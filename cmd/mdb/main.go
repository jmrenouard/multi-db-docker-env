package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"sync"

	"github.com/jmrenouard/multi-db-docker-env/pkg/config"
	"github.com/jmrenouard/multi-db-docker-env/pkg/dbclient"
	"github.com/jmrenouard/multi-db-docker-env/pkg/docker"
	"github.com/jmrenouard/multi-db-docker-env/pkg/interactive"
	"github.com/jmrenouard/multi-db-docker-env/pkg/pki"
	"github.com/jmrenouard/multi-db-docker-env/pkg/report"
	"github.com/jmrenouard/multi-db-docker-env/pkg/runner"
	"github.com/jmrenouard/multi-db-docker-env/pkg/topology"
)

var version = "2.4.1"

func resolveVersion() string {
	if data, err := os.ReadFile("VERSION"); err == nil {
		if v := strings.TrimSpace(string(data)); v != "" {
			return v
		}
	}
	return version
}

func runOrExit(err error) {
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func main() {
	if len(os.Args) < 2 {
		printUsage(os.Stdout)
		os.Exit(1)
	}

	ctx := context.Background()
	switch os.Args[1] {
	case "help", "--help", "-h":
		printUsage(os.Stdout)
	case "version", "--version", "-v":
		fmt.Printf("mdb version %s\n", resolveVersion())
	case "config":
		fs := flag.NewFlagSet("config", flag.ExitOnError)
		envPath := fs.String("env", "", "Path to .env file")
		_ = fs.Parse(os.Args[2:])
		cfg, err := config.Load(*envPath)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
		data, _ := json.MarshalIndent(cfg, "", "  ")
		fmt.Println(string(data))
	case "pki":
		if len(os.Args) < 3 {
			fmt.Println("Usage: mdb pki <generate|verify> [topology] [--dir <dir>]")
			os.Exit(1)
		}
		action, dir, topo := os.Args[2], "ssl", "all"
		for i := 3; i < len(os.Args); i++ {
			if os.Args[i] == "--dir" && i+1 < len(os.Args) {
				dir = os.Args[i+1]
				i++
			} else if !strings.HasPrefix(os.Args[i], "-") {
				topo = os.Args[i]
			}
		}
		engine := pki.NewPKIEngine(dir)
		if action == "generate" {
			if err := engine.GenerateTopologyCerts(topo); err != nil {
				fmt.Fprintf(os.Stderr, "Error: %v\n", err)
				os.Exit(1)
			}
			fmt.Printf("Certificates for %s generated in %s\n", topo, dir)
		} else if action == "verify" {
			if ok, err := engine.VerifyTopologyCerts(topo); !ok || err != nil {
				fmt.Fprintf(os.Stderr, "Verify failed: %v\n", err)
				os.Exit(1)
			}
			fmt.Printf("Certificates for %s are valid in %s\n", topo, dir)
		} else {
			fmt.Fprintf(os.Stderr, "Unknown PKI action: %s\nUsage: mdb pki <generate|verify> [topology] [--dir <dir>]\n", action)
			os.Exit(1)
		}
	case "catalog", "list", "envs", "environments", "topologies":
		runOrExit(runCatalogCmd(os.Args[2:], activeCatalog(), os.Stdout))
	case "up":
		if len(os.Args) < 3 {
			fmt.Println("Usage: mdb up <env>")
			os.Exit(1)
		}
		target := os.Args[2]
		runOrExit(runUpCmd(ctx, docker.NewClient(), activeCatalog(), target))
		fmt.Printf("Environment %s up successful\n", target)
	case "start":
		target := resolveDefaultEnv()
		if len(os.Args) >= 3 {
			target = os.Args[2]
		}
		runOrExit(runUpCmd(ctx, docker.NewClient(), activeCatalog(), target))
		fmt.Printf("Environment %s started\n", target)
	case "down", "stop":
		target := ""
		if len(os.Args) >= 3 {
			target = os.Args[2]
		}
		runOrExit(runDownCmd(ctx, docker.NewClient(), activeCatalog(), target))
		fmt.Println("Stop completed successfully")
	case "status":
		runOrExit(runStatusCmd(ctx, docker.NewClient(), activeCatalog(), os.Args[2:], os.Stdout))
	case "info":
		runOrExit(runInfoCmd(ctx, docker.NewClient(), os.Stdout))
	case "logs":
		runOrExit(runLogsCmd(ctx, docker.NewClient(), activeCatalog(), os.Args[2:]))
	case "client":
		runOrExit(runClientCmd(ctx, docker.NewClient(), activeCatalog(), os.Args[2:], os.Stderr))
	case "mycnf":
		runOrExit(runMyCnfCmd(os.Stdout, os.Stderr))
	case "doctor":
		runOrExit(runDoctorCmd(ctx, os.Stdout, runtime.GOOS, exec.LookPath, os.Stat, docker.NewClient()))
	case "profiles":
		runOrExit(streamCommand(ctx, nil, nil, os.Stdout, os.Stderr, "bash", "./scripts/gen_profiles.sh"))
	case "inject":
		runOrExit(runInjectCmd(ctx, docker.NewClient(), activeCatalog(), os.Args[2:]))
	case "backup":
		runOrExit(runBackupRestore(ctx, false, os.Args[2:]))
	case "restore":
		runOrExit(runBackupRestore(ctx, true, os.Args[2:]))
	case "audit":
		runOrExit(runAuditCmd(ctx, os.Args[2:]))
	case "clean":
		runOrExit(runCleanCmd(ctx, docker.NewClient(), activeCatalog(), os.Args[2:]))
	case "interactive", "wizard":
		opts, err := interactive.ParseArgs(os.Args[2:])
		runOrExit(err)
		opts.Catalog = activeCatalog()
		runOrExit(interactive.Run(ctx, opts))
	case "setup":
		runOrExit(runSetupCmd(ctx, activeCatalog(), os.Args[2:], os.Stdout, os.Stderr, streamCommand))
	case "lint":
		runOrExit(runLintCmd(ctx, docker.NewClient(), os.Stdout, os.Stderr))
	case "test":
		runOrExit(runTestCmd(ctx, docker.NewClient(), activeCatalog(), os.Args[2:], os.Stdout, os.Stderr, streamCommand))
	case "bench":
		runOrExit(runBenchCmd(ctx, docker.NewClient(), activeCatalog(), os.Args[2:]))
	case "report":
		fs := flag.NewFlagSet("report", flag.ExitOnError)
		jsonOut := fs.String("json", "", "Path to export JSON telemetry report")
		htmlOut := fs.String("html", "", "Path to export HTML report")
		_ = fs.Parse(os.Args[2:])

		pass := loadPassword()
		rep := report.NewReport(resolveVersion())
		client, ctx := docker.NewClient(), context.Background()

		topos := fs.Args()
		if len(topos) == 0 {
			for _, t := range topology.DefaultRegistry().List() {
				topos = append(topos, t.Name())
			}
		}

		var mu sync.Mutex
		steps := make([]runner.Step, 0, len(topos))
		for _, name := range topos {
			n := name
			steps = append(steps, runner.Step{
				Name: "verify-" + n,
				Run: func(sCtx context.Context) error {
					v, err := dbclient.NewVerifier(n, dbclient.Config{Name: n, ClusterType: n, Container: resolveContainer(sCtx, client, n), Password: pass, Executor: client})
					if err != nil {
						return err
					}
					defer v.Close()
					h, err := v.VerifyCluster(sCtx)
					if h != nil {
						mu.Lock()
						rep.AddCluster(h)
						mu.Unlock()
					}
					return err
				},
			})
		}
		results, _ := runner.NewPipeline(steps...).Run(ctx)
		for _, res := range results {
			rep.AddStep(res)
		}

		rep.ComputeSummary()

		if *jsonOut != "" {
			if err := rep.SaveJSON(*jsonOut); err != nil {
				fmt.Fprintf(os.Stderr, "Error saving JSON report: %v\n", err)
				os.Exit(1)
			}
			fmt.Printf("JSON report saved to %s\n", *jsonOut)
		}
		if *htmlOut != "" {
			if err := rep.SaveHTML(*htmlOut); err != nil {
				fmt.Fprintf(os.Stderr, "Error saving HTML report: %v\n", err)
				os.Exit(1)
			}
			fmt.Printf("HTML report saved to %s\n", *htmlOut)
		}

		if *jsonOut == "" && *htmlOut == "" {
			data, _ := rep.ToJSON()
			fmt.Println(string(data))
		}
	default:
		fmt.Fprintf(os.Stderr, "Unknown command: %s\n", os.Args[1])
		os.Exit(1)
	}
}

func loadPassword() string {
	if cfg, err := config.Load(""); err == nil && cfg != nil {
		return cfg.RootPassword
	}
	return config.DefaultConfig().RootPassword
}

func defaultContainer(topo string) string {
	switch strings.ToLower(topo) {
	case "galera":
		return "galera_01"
	case "repli":
		return "mariadb_02"
	case "innodb":
		return "mysql_node1"
	case "patroni":
		return "node1"
	case "pgpool":
		return "pgpool"
	case "mongo":
		return "mongo1"
	case "mongo8":
		return "mongo8_n1"
	case "pg17-baseline":
		return "pg17_standalone"
	case "pg-streaming":
		return "pg_stream_primary"
	case "pg-logical":
		return "pg_logical_pub"
	case "pg-birep":
		return "pg_birep_node1"
	case "pg18-streaming":
		return "pg18_stream_primary"
	case "pg18-logical":
		return "pg18_logical_pub"
	case "pg18-birep":
		return "pg18_birep_node1"
	case "pgedge":
		return "pgedge_node1"
	case "bucardo":
		return "bucardo_node1"
	case "citus":
		return "citus_coord"
	case "cockroach":
		return "crdb_node1"
	case "yugabyte":
		return "yb_node1"
	case "yt-cluster":
		return "yt1"
	default:
		return "mariadb-11.8"
	}
}

func resolveContainer(ctx context.Context, client *docker.Client, topo string) string {
	base := defaultContainer(topo)
	if client != nil {
		if names, err := client.PS(ctx, "name="+base); err == nil && len(names) > 0 {
			return names[0]
		}
	}
	return base
}
