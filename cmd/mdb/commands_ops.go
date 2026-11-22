package main

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"time"

	"github.com/jmrenouard/multi-db-docker-env/pkg/catalog"
	"github.com/jmrenouard/multi-db-docker-env/pkg/docker"
	"github.com/jmrenouard/multi-db-docker-env/pkg/topology"
)

func buildClientCommand(engine, envID, container, pass string) ([]string, []string) {
	id, eng, ctr := strings.ToLower(envID), strings.ToLower(engine), strings.ToLower(container)
	switch {
	case id == "cockroach" || eng == "cockroachdb":
		return nil, []string{"/cockroach/cockroach", "sql", "--insecure", "--host=crdb_node1:26257"}
	case id == "yugabyte" || eng == "yugabytedb":
		return nil, []string{"/home/yugabyte/bin/ysqlsh", "-h", "yb-node1", "-p", "5433", "-U", "yugabyte", "-d", "labdb"}
	case id == "mongo" || id == "mongo8" || eng == "mongodb":
		return nil, []string{"mongosh", "--tls", "--tlsAllowInvalidCertificates", "--tlsCertificateKeyFile", "/etc/ssl/mongo/mongodb.pem"}
	case ctr == "pgpool" || (id == "pgpool" && !strings.HasPrefix(ctr, "pg_node")):
		return []string{"PGPASSWORD=" + pass}, []string{"psql", "-h", "127.0.0.1", "-p", "9999", "-U", "postgres"}
	case eng == "postgres" || strings.HasPrefix(id, "pg") || strings.HasPrefix(id, "postgres") || id == "patroni" || id == "bucardo" || id == "citus" || id == "yt-cluster":
		return []string{"PGPASSWORD=" + pass}, []string{"psql", "-U", "postgres"}
	default:
		return []string{"MYSQL_PWD=" + pass}, []string{"sh", "-c", "if command -v mariadb >/dev/null 2>&1; then exec mariadb -uroot; else exec mysql -uroot; fi"}
	}
}

func inferEngineAndID(cat *catalog.Catalog, st docker.ContainerStatus) (string, string) {
	if env, ok := cat.Lookup(st.Service); ok {
		return env.Engine, env.ID
	}
	for _, env := range cat.Filter("", "", true, false) {
		for _, cf := range env.ComposeFiles {
			if cf != "docker-compose.yml" && strings.Contains(st.File, cf) {
				return env.Engine, env.ID
			}
		}
	}
	s := strings.ToLower(st.Service + " " + st.Name)
	switch {
	case strings.Contains(s, "mongo"):
		return "mongodb", "mongo"
	case strings.Contains(s, "crdb") || strings.Contains(s, "cockroach"):
		return "cockroachdb", "cockroach"
	case strings.Contains(s, "yb") || strings.Contains(s, "yugabyte"):
		return "yugabytedb", "yugabyte"
	case strings.Contains(s, "pgpool"):
		return "postgres", "pgpool"
	case strings.Contains(s, "pg") || strings.Contains(s, "postgres") || strings.Contains(s, "citus") || strings.Contains(s, "bucardo") || strings.Contains(s, "node") || strings.Contains(s, "yt"):
		return "postgres", "postgres"
	default:
		return "mariadb", st.Service
	}
}

func resolveEnvContainer(ctx context.Context, client *docker.Client, cat *catalog.Catalog, target string) (string, catalog.Environment, bool) {
	env, ok := cat.Lookup(target)
	base := defaultContainer(target)
	if ok && env.Container != "" {
		base = env.Container
	}
	return client.ResolveContainer(ctx, base), env, ok
}

func runClientCmd(ctx context.Context, client *docker.Client, cat *catalog.Catalog, args []string, stderr io.Writer) error {
	pass := loadPasswordWarn(stderr)
	var ctr, engine, envID string
	if len(args) > 0 {
		target := args[0]
		resolved, env, ok := resolveEnvContainer(ctx, client, cat, target)
		if ok && env.Status == catalog.StatusEOL {
			return checkEOLError(env)
		}
		if !ok {
			if _, err := topology.DefaultRegistry().Get(target); err != nil {
				return fmt.Errorf("unknown environment: %s", target)
			}
		}
		if running, err := client.IsRunning(ctx, resolved); err != nil {
			return err
		} else if !running {
			return fmt.Errorf("container %s for %s is not running", resolved, target)
		}
		ctr, engine, envID = resolved, env.Engine, env.ID
		if envID == "" {
			envID = target
		}
	} else {
		items, err := client.ComposePSStatusAll(ctx, nil)
		if err != nil && len(items) == 0 {
			return err
		}
		primary, ok := pickPrimaryContainer(items)
		if !ok {
			return errors.New("no running database service found")
		}
		ctr = primary.Name
		engine, envID = inferEngineAndID(cat, primary)
	}
	envVars, cmdArgs := buildClientCommand(engine, envID, ctr, pass)
	dArgs := []string{"exec", "-i"}
	if fi, err := os.Stdin.Stat(); err == nil && (fi.Mode()&os.ModeCharDevice) != 0 {
		dArgs = []string{"exec", "-it"}
	}
	for _, e := range envVars {
		dArgs = append(dArgs, "-e", e)
	}
	return streamCommand(ctx, nil, os.Stdin, os.Stdout, os.Stderr, "docker", append(append(dArgs, ctr), cmdArgs...)...)
}

func writeMyCnf(homeDir, pass string) (bool, error) {
	cnf, bak := filepath.Join(homeDir, ".my.cnf"), filepath.Join(homeDir, ".my.cnf.bak")
	backedUp := false
	if prev, err := os.ReadFile(cnf); err == nil {
		if err := os.WriteFile(bak, prev, 0600); err != nil {
			return false, err
		}
		if err := os.Chmod(bak, 0600); err != nil {
			return false, err
		}
		backedUp = true
	} else if !errors.Is(err, os.ErrNotExist) {
		return false, err
	}
	port := strings.TrimSpace(os.Getenv("TRAEFIK_MYSQL_PORT"))
	if port == "" {
		port = "3306"
	}
	if err := os.WriteFile(cnf, []byte(fmt.Sprintf("[client]\nuser=root\npassword=%s\nhost=127.0.0.1\nport=%s\n", pass, port)), 0600); err != nil {
		return backedUp, err
	}
	return backedUp, os.Chmod(cnf, 0600)
}

var doctorPortBound = func(port string) bool {
	c, err := net.DialTimeout("tcp", "127.0.0.1:"+port, 150*time.Millisecond)
	if err != nil {
		return false
	}
	_ = c.Close()
	return true
}

func runMyCnfCmd(stdout, stderr io.Writer) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	backedUp, err := writeMyCnf(home, loadPasswordWarn(stderr))
	if err != nil {
		return err
	}
	if backedUp {
		fmt.Fprintf(stdout, "Backed up %s to %s (0600)\n", filepath.Join(home, ".my.cnf"), filepath.Join(home, ".my.cnf.bak"))
	}
	fmt.Fprintf(stdout, "Wrote %s (0600)\n", filepath.Join(home, ".my.cnf"))
	return nil
}

func runDoctorCmd(ctx context.Context, w io.Writer, goos string, lookPath func(string) (string, error), stat func(string) (os.FileInfo, error), client *docker.Client) error {
	fmt.Fprintf(w, "Platform: %s/%s\n", goos, runtime.GOARCH)
	if goos == "windows" {
		fmt.Fprintln(w, "Note: Use mdb.cmd natively; Git Bash or WSL2 is recommended for bash-backed scripts.")
	} else if goos == "darwin" {
		fmt.Fprintln(w, "Note: Ensure Docker Desktop is running and Homebrew tools (bash, openssl) are on PATH.")
	}
	missing := false
	for _, tool := range []string{"docker", "go", "openssl", "bash"} {
		if p, err := lookPath(tool); err == nil {
			fmt.Fprintf(w, "[OK]      %-10s %s\n", tool, p)
		} else if tool == "docker" {
			fmt.Fprintf(w, "[MISSING] %-10s not found on PATH\n", tool)
			missing = true
		} else {
			fmt.Fprintf(w, "[WARN]    %-10s not found on PATH\n", tool)
		}
	}
	if client != nil {
		if out, _, code, err := client.Runner().Run(ctx, "docker", "compose", "version"); err == nil && code == 0 {
			fmt.Fprintf(w, "[OK]      compose    %s\n", strings.TrimSpace(string(out)))
		} else {
			fmt.Fprintln(w, "[MISSING] compose    docker compose v2 unavailable")
			missing = true
		}
		if out, _, code, err := client.Runner().Run(ctx, "docker", "info", "--format", "{{.ServerVersion}}"); err == nil && code == 0 {
			fmt.Fprintf(w, "[OK]      daemon     running (%s)\n", strings.TrimSpace(string(out)))
		} else {
			fmt.Fprintln(w, "[WARN]    daemon     Docker daemon not reachable")
		}
	}
	if _, err := stat(".env"); err == nil {
		fmt.Fprintln(w, "[OK]      .env       present")
	} else {
		fmt.Fprintln(w, "[WARN]    .env       missing (using default 'rootpass')")
	}
	for _, p := range []struct{ port, env string }{{"3306", "TRAEFIK_MYSQL_PORT"}, {"5432", "TRAEFIK_PG_PORT"}} {
		if doctorPortBound(p.port) {
			fmt.Fprintf(w, "[WARN]    port %-5s already bound on localhost (set %s=<port> to override)\n", p.port, p.env)
		} else {
			fmt.Fprintf(w, "[OK]      port %-5s available\n", p.port)
		}
	}
	for _, d := range []string{"ssl", "ssl/innodb", "ssl/pgpool", "ssl/mongo", "ssl/certs/mongo8", "certs_patroni"} {
		if _, err := stat(d); err == nil {
			fmt.Fprintf(w, "[OK]      %-16s present\n", d)
		} else {
			fmt.Fprintf(w, "[INFO]    %-16s missing (auto-generated on 'mdb up')\n", d)
		}
	}
	if missing {
		return errors.New("doctor detected missing critical dependencies")
	}
	return nil
}
