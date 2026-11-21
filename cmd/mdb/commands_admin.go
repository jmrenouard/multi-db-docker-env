package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/jmrenouard/multi-db-docker-env/pkg/catalog"
	"github.com/jmrenouard/multi-db-docker-env/pkg/docker"
)

func runInjectCmd(ctx context.Context, client *docker.Client, cat *catalog.Catalog, args []string) error {
	if len(args) < 1 {
		return errors.New("usage: mdb inject <employees|sakila> [service]")
	}
	dbName := strings.ToLower(args[0])
	if dbName != "employees" && dbName != "sakila" {
		return fmt.Errorf("unsupported dataset %q (expected employees or sakila)", dbName)
	}
	target := ""
	if len(args) > 1 {
		target = args[1]
	} else {
		items, err := client.ComposePSStatusAll(ctx, nil)
		if err != nil && len(items) == 0 {
			return err
		}
		primary, ok := pickPrimaryContainer(items)
		if !ok {
			return errors.New("no running database service detected for injection")
		}
		target = primary.Service
	}
	env, ok := cat.Lookup(target)
	if ok && env.Status == catalog.StatusEOL {
		return checkEOLError(env)
	}
	if ok && env.Engine != "mysql" && env.Engine != "mariadb" && env.Engine != "percona" {
		fmt.Printf("Skipping data injection for %s (%s): MySQL/MariaDB datasets only.\n", env.ID, env.Engine)
		return nil
	}
	ctr, _, _ := resolveEnvContainer(ctx, client, cat, target)
	if strings.EqualFold(target, "repli") {
		if names, err := client.PS(ctx, "name=mariadb_01"); err == nil && len(names) > 0 {
			ctr = names[0]
		}
	}
	if running, err := client.IsRunning(ctx, ctr); err != nil || !running {
		return fmt.Errorf("container %s is not running", ctr)
	}
	pass := loadPasswordWarn(os.Stderr)
	for i := 0; i < 30; i++ {
		if _, err := client.Exec(ctx, ctr, []string{"MYSQL_PWD=" + pass}, "sh", "-c", "mariadb -uroot -e 'SELECT 1' >/dev/null 2>&1 || mysql -uroot -e 'SELECT 1' >/dev/null 2>&1"); err == nil {
			break
		}
		time.Sleep(2 * time.Second)
	}
	if _, err := os.Stat(filepath.Join("test_db", "employees", "employees.sql")); err != nil {
		if err := streamCommand(ctx, nil, nil, os.Stdout, os.Stderr, "git", "submodule", "update", "--init", "--recursive", "test_db"); err != nil {
			return err
		}
	}
	if strings.EqualFold(target, "mysql97") && dbName == "employees" {
		fmt.Println("Note: substituting 'sakila' for mysql97 (nested source compatibility).")
		dbName = "sakila"
	}
	if err := streamCommand(ctx, nil, nil, os.Stdout, os.Stderr, "docker", "cp", filepath.ToSlash(filepath.Join("test_db", dbName)), ctr+":/tmp/"); err != nil {
		return err
	}
	sqlCmd := "cd /tmp/employees && (mariadb -uroot < employees.sql || mysql -uroot < employees.sql)"
	if dbName == "sakila" {
		sqlCmd = "cd /tmp/sakila && (mariadb -uroot < sakila-mv-schema.sql && mariadb -uroot < sakila-mv-data.sql || mysql -uroot < sakila-mv-schema.sql && mysql -uroot < sakila-mv-data.sql)"
	}
	return streamCommand(ctx, nil, nil, os.Stdout, os.Stderr, "docker", "exec", "-i", "-e", "MYSQL_PWD="+pass, ctr, "sh", "-c", sqlCmd)
}

func planBackupRestore(isRestore bool, args []string) (string, []string, error) {
	fs := flag.NewFlagSet("br", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	phys := fs.Bool("physical", false, "")
	flags, pos := splitFlagsAndArgs(args, map[string]bool{"physical": true})
	if err := fs.Parse(flags); err != nil {
		return "", nil, err
	}
	if !isRestore {
		if len(pos) < 1 || (pos[0] != "galera" && pos[0] != "repli") {
			return "", nil, errors.New("usage: mdb backup <galera|repli> [db] [--physical]")
		}
		if *phys {
			return "./scripts/backup_physical.sh", []string{pos[0]}, nil
		}
		return "./scripts/backup_logical.sh", pos, nil
	}
	if len(pos) < 2 || (pos[0] != "galera" && pos[0] != "repli") {
		return "", nil, errors.New("usage: mdb restore <galera|repli> <file> [--physical]")
	}
	if *phys {
		return "./scripts/restore_physical.sh", []string{pos[0], pos[1]}, nil
	}
	return "./scripts/restore_logical.sh", []string{pos[0], pos[1]}, nil
}

func runBackupRestore(ctx context.Context, isRestore bool, args []string) error {
	script, sArgs, err := planBackupRestore(isRestore, args)
	if err != nil {
		return err
	}
	return streamCommand(ctx, nil, nil, os.Stdout, os.Stderr, "bash", append([]string{script}, sArgs...)...)
}

func auditTargets(arg string) ([]string, error) {
	tMap := map[string]string{"galera": "galera", "innodb": "innodb_cluster", "repli": "replication"}
	if arg == "all" {
		return []string{"galera", "innodb_cluster", "replication"}, nil
	}
	if m, ok := tMap[arg]; ok {
		return []string{m}, nil
	}
	return nil, fmt.Errorf("unknown audit target %q (expected galera|innodb|repli|all)", arg)
}

func runAuditCmd(ctx context.Context, args []string) error {
	if len(args) < 1 {
		return errors.New("usage: mdb audit <galera|innodb|repli|all>")
	}
	targets, err := auditTargets(args[0])
	if err != nil {
		return err
	}
	for _, t := range targets {
		if err := streamCommand(ctx, nil, nil, os.Stdout, os.Stderr, "bash", "./scripts/run_mysqltuner.sh", "--topology", t); err != nil {
			return err
		}
	}
	return nil
}

func wslMountPath(p string) string {
	if len(p) >= 2 && p[1] == ':' {
		return "/mnt/" + strings.ToLower(p[:1]) + strings.ReplaceAll(p[2:], `\`, "/")
	}
	return p
}

func runAlpineCleanup(ctx context.Context, client *docker.Client, wd string, failed []string) error {
	buildArgs := func(src string) []string {
		rmArgs := []string{"run", "--rm", "--mount", fmt.Sprintf("type=bind,source=%s,target=/workspace", src), "alpine", "rm", "-rf"}
		for _, f := range failed {
			rmArgs = append(rmArgs, "/workspace/"+filepath.ToSlash(f))
		}
		return rmArgs
	}
	_, se, code, err := client.Runner().Run(ctx, "docker", buildArgs(wd)...)
	if (err != nil || code != 0) && wslMountPath(wd) != wd {
		_, se, code, err = client.Runner().Run(ctx, "docker", buildArgs(wslMountPath(wd))...)
	}
	if err != nil || code != 0 {
		return fmt.Errorf("cleanup failed (%d): %s: %w", code, strings.TrimSpace(string(se)), err)
	}
	return nil
}

func removeGlobs(ctx context.Context, client *docker.Client, patterns ...string) error {
	var failed []string
	for _, pat := range patterns {
		matches, _ := filepath.Glob(pat)
		for _, m := range matches {
			if err := os.RemoveAll(m); err != nil {
				failed = append(failed, m)
			}
		}
	}
	if len(failed) > 0 && client != nil {
		if wd, err := os.Getwd(); err == nil {
			return runAlpineCleanup(ctx, client, wd, failed)
		}
	}
	return nil
}

func runCleanCmd(ctx context.Context, client *docker.Client, cat *catalog.Catalog, args []string) error {
	if len(args) < 1 {
		return errors.New("usage: mdb clean <galera|repli|ssl|data|reports|all>")
	}
	switch strings.ToLower(args[0]) {
	case "galera":
		_ = runDownCmd(ctx, client, cat, "galera")
		return removeGlobs(ctx, client, "gdatadir_*", "gbackups_*")
	case "repli":
		_ = runDownCmd(ctx, client, cat, "repli")
		return removeGlobs(ctx, client, "datadir_*", "backups_*")
	case "ssl":
		return removeGlobs(ctx, client, "ssl", "certs_patroni")
	case "reports":
		return removeGlobs(ctx, client, "reports/*.md", "reports/*.html")
	case "data":
		if err := client.ComposeDownAll(ctx, nil, docker.ProjectName()); err != nil {
			return err
		}
		return removeGlobs(ctx, client, "gdatadir_*", "gbackups_*", "datadir_*", "backups_*", "ssl", "certs_patroni")
	case "all":
		if err := client.ComposeDownAll(ctx, nil, docker.ProjectName()); err != nil {
			return err
		}
		return removeGlobs(ctx, client, "gdatadir_*", "gbackups_*", "datadir_*", "backups_*", "ssl", "certs_patroni", "reports/*.md", "reports/*.html")
	default:
		return fmt.Errorf("unknown clean target %q", args[0])
	}
}
