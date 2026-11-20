package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
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
		res, err := bench.NewSysbenchRunner(bench.SysbenchConfig{
			Workload: *workload, Container: ctr, User: "root", Password: loadPasswordWarn(os.Stderr),
			Threads: *threads, Duration: *duration, Executor: client,
		}).Run(ctx)
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
		if err := streamCommand(ctx, nil, nil, os.Stdout, os.Stderr, "docker", append(append([]string{}, base...), "-i", "-s", "1", "-U", "postgres")...); err != nil {
			return err
		}
		return streamCommand(ctx, nil, nil, os.Stdout, os.Stderr, "docker", append(append([]string{}, base...), "-c", thr, "-T", sec, "-U", "postgres")...)
	}
}
