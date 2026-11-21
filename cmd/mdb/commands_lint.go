package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"io/fs"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"

	"github.com/jmrenouard/multi-db-docker-env/pkg/catalog"
	"github.com/jmrenouard/multi-db-docker-env/pkg/dbclient"
	"github.com/jmrenouard/multi-db-docker-env/pkg/docker"
	"github.com/jmrenouard/multi-db-docker-env/pkg/topology"
)

type scriptExecFunc func(context.Context, []string, io.Reader, io.Writer, io.Writer, string, ...string) error

func planSetup(cat *catalog.Catalog, target string) (string, []string, []string, bool, error) {
	env, ok := cat.Lookup(target)
	if ok && env.Status == catalog.StatusEOL {
		return "", nil, nil, false, checkEOLError(env)
	}
	if !ok {
		if _, err := topology.DefaultRegistry().Get(target); err != nil {
			return "", nil, nil, false, fmt.Errorf("unknown environment: %s", target)
		}
		return "", nil, nil, false, nil
	}
	if env.SetupScript == "" {
		return "", nil, nil, false, nil
	}
	if strings.EqualFold(env.ID, "mongo8") {
		return env.SetupScript, []string{"mongo8_n1", "mongo8_n2", "mongo8_n3"}, []string{"MONGO_NODES=mongo8_n1 mongo8_n2 mongo8_n3"}, true, nil
	}
	return env.SetupScript, nil, nil, true, nil
}

func withDefaultPasswordEnv(base []string) []string {
	env := append([]string(nil), base...)
	if os.Getenv("DB_ROOT_PASSWORD") == "" {
		env = append(env, "DB_ROOT_PASSWORD="+loadPassword())
	}
	return env
}

func runSetupCmd(ctx context.Context, cat *catalog.Catalog, args []string, stdout, stderr io.Writer, execFn scriptExecFunc) error {
	if len(args) < 1 {
		return errors.New("usage: mdb setup <env>")
	}
	script, sArgs, sEnv, has, err := planSetup(cat, args[0])
	if err != nil {
		return err
	}
	if !has {
		fmt.Fprintf(stdout, "No setup script required for %s.\n", args[0])
		return nil
	}
	if _, err := os.Stat(script); err != nil {
		return fmt.Errorf("setup script %s not found: %w", script, err)
	}
	fmt.Fprintf(stdout, "Running %s for %s...\n", script, args[0])
	return execFn(ctx, withDefaultPasswordEnv(sEnv), nil, stdout, stderr, "bash", append([]string{script}, sArgs...)...)
}

func discoverLintFiles(ctx context.Context) (sh, compose []string) {
	add := func(p string) {
		if p = filepath.ToSlash(strings.TrimSpace(p)); p == "" {
			return
		}
		if b := filepath.Base(p); strings.HasSuffix(b, ".sh") {
			sh = append(sh, p)
		} else if strings.HasPrefix(b, "docker-compose") && strings.HasSuffix(b, ".yml") {
			compose = append(compose, p)
		}
	}
	if out, err := exec.CommandContext(ctx, "git", "ls-files", "*.sh", "docker-compose*.yml").Output(); err == nil && len(strings.TrimSpace(string(out))) > 0 {
		for _, line := range strings.Split(string(out), "\n") {
			add(line)
		}
	} else {
		_ = filepath.WalkDir(".", func(p string, d fs.DirEntry, _ error) error {
			if d != nil && d.IsDir() && (d.Name() == ".git" || d.Name() == "test_db" || d.Name() == "reports") {
				return filepath.SkipDir
			}
			if d != nil && !d.IsDir() {
				add(p)
			}
			return nil
		})
	}
	sort.Strings(sh)
	sort.Strings(compose)
	return sh, compose
}

func runLintCmd(ctx context.Context, client *docker.Client, stdout, stderr io.Writer) error {
	shFiles, composeFiles := discoverLintFiles(ctx)
	if len(shFiles) == 0 && len(composeFiles) == 0 {
		return errors.New("no lint targets found")
	}
	var errs []string
	if len(shFiles) > 0 {
		bArgs := append([]string{"-c", `rc=0; for f in "$@"; do bash -n "$f" || rc=1; done; exit $rc`, "_"}, shFiles...)
		if _, se, code, err := client.Runner().Run(ctx, "bash", bArgs...); err != nil || code != 0 {
			if m := strings.TrimSpace(string(se)); m != "" {
				fmt.Fprintln(stderr, m)
			}
			errs = append(errs, fmt.Sprintf("bash -n (%d)", code))
		} else {
			fmt.Fprintf(stdout, "[OK]   bash -n passed for %d shell script(s)\n", len(shFiles))
		}
	}
	base := []string{"compose"}
	if _, err := os.Stat(".env"); err != nil {
		if _, ex := os.Stat(".env.example"); ex == nil {
			base = append(base, "--env-file", ".env.example")
		}
	}
	for _, cf := range composeFiles {
		cArgs := append(append([]string{}, base...), "-f", cf, "config", "-q")
		if _, se, code, err := client.Runner().Run(ctx, "docker", cArgs...); err != nil || code != 0 {
			fmt.Fprintf(stderr, "[FAIL] %s: %s\n", cf, strings.TrimSpace(string(se)))
			errs = append(errs, cf)
		} else {
			fmt.Fprintf(stdout, "[OK]   %s\n", cf)
		}
	}
	if len(errs) > 0 {
		return fmt.Errorf("lint failed: %s", strings.Join(errs, ", "))
	}
	return nil
}

func suiteScriptPath(name string) string {
	switch id := strings.ToLower(strings.TrimSpace(name)); id {
	case "innodb":
		return "tests/test_innodb_cluster.sh"
	case "mongo", "mongo8":
		return "tests/test_mongo_rs.sh"
	default:
		return "tests/test_" + strings.ReplaceAll(id, "-", "_") + ".sh"
	}
}

func runTestCmd(ctx context.Context, client *docker.Client, cat *catalog.Catalog, args []string, stdout, stderr io.Writer, execFn scriptExecFunc) error {
	fs := flag.NewFlagSet("test", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	suite := fs.Bool("suite", false, "")
	flags, pos := splitFlagsAndArgs(args, map[string]bool{"suite": true})
	if err := fs.Parse(flags); err != nil {
		return err
	}
	if len(pos) < 1 {
		return errors.New("Usage: mdb test <topology> [--suite]")
	}
	name := pos[0]
	env, ok := cat.Lookup(name)
	if ok && env.Status == catalog.StatusEOL {
		return checkEOLError(env)
	}
	vType := name
	if _, err := topology.DefaultRegistry().Get(name); err != nil {
		if !ok {
			return err
		}
		if vType = env.Engine; vType == "percona" {
			vType = "mysql"
		}
	}
	ctr, _, _ := resolveEnvContainer(ctx, client, cat, name)
	v, err := dbclient.NewVerifier(vType, dbclient.Config{Name: name, ClusterType: vType, Container: ctr, Password: loadPassword(), Executor: client})
	if err != nil {
		return fmt.Errorf("verifier error: %w", err)
	}
	defer v.Close()
	health, err := v.VerifyCluster(ctx)
	if health != nil {
		data, _ := json.MarshalIndent(health, "", "  ")
		fmt.Fprintln(stdout, string(data))
	}
	if err != nil || health == nil || health.Status == dbclient.StatusUnhealthy {
		return fmt.Errorf("verification failed for %s: %v", name, err)
	}
	if *suite {
		script := suiteScriptPath(name)
		if _, err := os.Stat(script); err != nil {
			return fmt.Errorf("suite %s not found: %w", script, err)
		}
		var sEnv, sArgs []string
		if strings.EqualFold(name, "mongo8") {
			sEnv = []string{"MONGO_NODES=mongo8_n1 mongo8_n2 mongo8_n3"}
			sArgs = []string{"mongo8_n1", "mongo8_n2", "mongo8_n3"}
		}
		return execFn(ctx, withDefaultPasswordEnv(sEnv), nil, stdout, stderr, "bash", append([]string{script}, sArgs...)...)
	}
	return nil
}
