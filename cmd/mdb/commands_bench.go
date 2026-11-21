package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"strings"
	"time"

	"github.com/jmrenouard/multi-db-docker-env/pkg/bench"
	"github.com/jmrenouard/multi-db-docker-env/pkg/catalog"
	"github.com/jmrenouard/multi-db-docker-env/pkg/docker"
	"github.com/jmrenouard/multi-db-docker-env/pkg/topology"
)

type benchPlan struct {
	Strategy, Script, Arg, Message string
	Env                            []string
}

var (
	pgV2BenchMap = map[string]string{
		"postgres17": "pg17-standalone", "pg-streaming": "pg17-async-streaming", "pg-logical": "pg17-logical",
		"pg-birep": "pg-birep", "pgedge": "pgedge", "bucardo": "bucardo", "citus": "citus", "cockroach": "cockroach", "yugabyte": "yugabyte",
	}
	pg18BenchMap = map[string]string{
		"pg18-streaming": "pg18-async-streaming", "pg18-logical": "pg18-logical", "pg18-birep": "pg18-birep",
	}
)

func planBenchmark(env catalog.Environment) benchPlan {
	switch {
	case env.Engine == "mysql" || env.Engine == "mariadb" || env.Engine == "percona":
		return benchPlan{Strategy: "sysbench", Message: fmt.Sprintf("Running sysbench against %s (%s)", env.ID, env.Container)}
	case env.Engine == "mongodb":
		node := env.Container
		if node == "" {
			node = "mongo1"
		}
		return benchPlan{Strategy: "mongo-script", Script: "./tests/test_perf_mongo.sh", Env: []string{"MONGO_NODE1=" + node}, Message: fmt.Sprintf("Routing MongoDB benchmark for %s via ./tests/test_perf_mongo.sh", env.ID)}
	case env.ID == "yt-cluster":
		return benchPlan{Strategy: "yt-script", Script: "./scripts/bench_yt_runner.sh", Message: "Routing YT Cluster benchmark via ./scripts/bench_yt_runner.sh"}
	case pg18BenchMap[env.ID] != "":
		return benchPlan{Strategy: "pg18-script", Script: "./scripts/bench_pg18_runner.sh", Arg: pg18BenchMap[env.ID], Message: fmt.Sprintf("Routing PG 18 benchmark for %s (%s)", env.ID, pg18BenchMap[env.ID])}
	case pgV2BenchMap[env.ID] != "":
		return benchPlan{Strategy: "pg-v2-script", Script: "./scripts/bench_pg_v2_runner.sh", Arg: pgV2BenchMap[env.ID], Message: fmt.Sprintf("Routing PostgreSQL V2 benchmark for %s (%s)", env.ID, pgV2BenchMap[env.ID])}
	default:
		return benchPlan{Strategy: "pgbench", Message: fmt.Sprintf("Running container pgbench against %s (%s)", env.ID, env.Container)}
	}
}

func runMySQLSysbench(ctx context.Context, client *docker.Client, ctr, workload, pass string, threads int, duration time.Duration) (*bench.SysbenchResult, error) {
	if workload == "" || strings.ContainsAny(workload, " \t\n\r;'\"$`\\&|<>") {
		return nil, fmt.Errorf("invalid sysbench workload %q", workload)
	}
	sec, thr := max(1, int(duration.Seconds())), max(1, threads)
	if _, err := client.Exec(ctx, ctr, []string{"MYSQL_PWD=" + pass}, "sh", "-c", "if command -v mariadb >/dev/null 2>&1; then mariadb -uroot -e 'CREATE DATABASE IF NOT EXISTS sbtest;'; else mysql -uroot -e 'CREATE DATABASE IF NOT EXISTS sbtest;'; fi"); err != nil {
		return nil, fmt.Errorf("create sbtest db failed: %w", err)
	}
	if _, err := client.Exec(ctx, ctr, nil, "sh", "-c", "command -v sysbench >/dev/null 2>&1"); err == nil {
		script := fmt.Sprintf(`sb="sysbench %s --db-driver=mysql --mysql-user=root --mysql-db=sbtest --tables=1 --table-size=1000"; $sb --mysql-password="$MYSQL_PWD" cleanup >/dev/null 2>&1 || true; $sb --mysql-password="$MYSQL_PWD" prepare >/dev/null && $sb --mysql-password="$MYSQL_PWD" --threads=%d --time=%d run`, workload, thr, sec)
		out, err := client.Exec(ctx, ctr, []string{"MYSQL_PWD=" + pass}, "sh", "-c", script)
		if err != nil {
			return nil, fmt.Errorf("sysbench execution failed: %w", err)
		}
		res, err := bench.ParseSysbenchOutput(out)
		if err == nil && res.Workload == "" {
			res.Workload = workload
		}
		return res, err
	}
	netOut, se, code, err := client.Runner().Run(ctx, "docker", "inspect", "-f", "{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}", ctr)
	if err != nil || code != 0 {
		return nil, fmt.Errorf("inspect container network failed (%d): %s: %w", code, strings.TrimSpace(string(se)), err)
	}
	nets := strings.Fields(string(netOut))
	if len(nets) == 0 {
		return nil, fmt.Errorf("no docker network found for %s", ctr)
	}
	img := "mariadb_ssh:004"
	if ok, _ := client.ImageExists(ctx, img); !ok {
		if ok2, _ := client.ImageExists(ctx, "multi-db-pgbench-sysbench:latest"); ok2 {
			img = "multi-db-pgbench-sysbench:latest"
		} else if bErr := client.BuildImage(ctx, img, "."); bErr != nil {
			return nil, bErr
		}
	}
	script := fmt.Sprintf(`sb="sysbench %s --db-driver=mysql --mysql-host=%s --mysql-port=3306 --mysql-user=root --mysql-db=sbtest --tables=1 --table-size=1000"; $sb --mysql-password="$MYSQL_PWD" cleanup >/dev/null 2>&1 || true; if ! $sb --mysql-password="$MYSQL_PWD" prepare >/dev/null 2>&1; then sb="$sb --mysql-ssl=on"; $sb --mysql-password="$MYSQL_PWD" cleanup >/dev/null 2>&1 || true; $sb --mysql-password="$MYSQL_PWD" prepare >/dev/null; fi && $sb --mysql-password="$MYSQL_PWD" --threads=%d --time=%d run`, workload, ctr, thr, sec)
	out, se, code, err := client.RunWithEnv(ctx, []string{"MYSQL_PWD=" + pass}, "docker", "run", "--rm", "--entrypoint", "sh", "--network", nets[0], "-e", "MYSQL_PWD", img, "-c", script)
	if err != nil || code != 0 {
		return nil, fmt.Errorf("sysbench container failed (%d): %s: %w", code, strings.TrimSpace(string(se)), err)
	}
	res, err := bench.ParseSysbenchOutput(string(out))
	if err == nil && res.Workload == "" {
		res.Workload = workload
	}
	return res, err
}

func runBenchCmd(ctx context.Context, client *docker.Client, cat *catalog.Catalog, args []string) error {
	fs := flag.NewFlagSet("bench", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	workload := fs.String("workload", "oltp_read_write", "")
	threads := fs.Int("threads", 4, "")
	duration := fs.Duration("duration", 10*time.Second, "")
	flags, pos := splitFlagsAndArgs(args, nil)
	if err := fs.Parse(flags); err != nil {
		return err
	}
	if len(pos) < 1 {
		return errors.New("usage: mdb bench <env> [--workload <w>] [--threads <n>] [--duration <d>]")
	}
	name := pos[0]
	env, ok := cat.Lookup(name)
	if ok && env.Status == catalog.StatusEOL {
		return checkEOLError(env)
	}
	if !ok {
		if _, err := topology.DefaultRegistry().Get(name); err != nil {
			return err
		}
		env = catalog.Environment{ID: name, Engine: "mariadb", Container: defaultContainer(name)}
	}
	plan := planBenchmark(env)
	fmt.Println(plan.Message)
	switch plan.Strategy {
	case "sysbench":
		ctr, _, _ := resolveEnvContainer(ctx, client, cat, env.ID)
		res, err := runMySQLSysbench(ctx, client, ctr, *workload, loadPasswordWarn(os.Stderr), *threads, *duration)
		if err != nil {
			return err
		}
		data, _ := res.ToJSON()
		fmt.Println(data)
		return nil
	case "mongo-script":
		if err := streamCommand(ctx, plan.Env, nil, os.Stdout, os.Stderr, "bash", plan.Script, "light", "prepare"); err != nil {
			return err
		}
		return streamCommand(ctx, plan.Env, nil, os.Stdout, os.Stderr, "bash", plan.Script, "light", "run")
	case "pg18-script", "pg-v2-script", "yt-script":
		sArgs := []string{plan.Script}
		if plan.Arg != "" {
			sArgs = append(sArgs, plan.Arg)
		}
		return streamCommand(ctx, nil, nil, os.Stdout, os.Stderr, "bash", sArgs...)
	default:
		ctr, _, _ := resolveEnvContainer(ctx, client, cat, env.ID)
		pass := loadPasswordWarn(os.Stderr)
		sec, thr := fmt.Sprintf("%d", max(1, int(duration.Seconds()))), fmt.Sprintf("%d", max(1, *threads))
		base := []string{"exec", "-e", "PGPASSWORD=" + pass, ctr, "pgbench"}
		if env.ID == "pgpool" {
			base = append(base, "-h", "127.0.0.1", "-p", "9999")
		}
		if err := streamCommand(ctx, nil, nil, os.Stdout, os.Stderr, "docker", append(append([]string{}, base...), "-i", "-s", "1", "-U", "postgres", "postgres")...); err != nil {
			return err
		}
		return streamCommand(ctx, nil, nil, os.Stdout, os.Stderr, "docker", append(append([]string{}, base...), "-c", thr, "-T", sec, "-U", "postgres", "postgres")...)
	}
}
