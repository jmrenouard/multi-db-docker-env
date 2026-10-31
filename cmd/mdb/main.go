package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/jmrenouard/multi-db-docker-env/pkg/bench"
	"github.com/jmrenouard/multi-db-docker-env/pkg/config"
	"github.com/jmrenouard/multi-db-docker-env/pkg/dbclient"
	"github.com/jmrenouard/multi-db-docker-env/pkg/docker"
	"github.com/jmrenouard/multi-db-docker-env/pkg/pki"
	"github.com/jmrenouard/multi-db-docker-env/pkg/report"
	"github.com/jmrenouard/multi-db-docker-env/pkg/topology"
)

var version = "1.3.43"

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: mdb <version|config|pki|up|down|status|topologies|test|bench|report> [options]")
		os.Exit(1)
	}

	switch os.Args[1] {
	case "version", "--version", "-v":
		fmt.Printf("mdb version %s\n", version)
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
	case "topologies":
		for _, t := range topology.DefaultRegistry().List() {
			fmt.Printf("%-12s - %s\n", t.Name(), t.Description())
		}
	case "up", "down", "status":
		cmd := os.Args[1]
		if len(os.Args) < 3 {
			fmt.Printf("Usage: mdb %s <topology>\n", cmd)
			os.Exit(1)
		}
		name := os.Args[2]
		topo, err := topology.DefaultRegistry().Get(name)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
		client, ctx := docker.NewClient(), context.Background()
		var actionErr error
		if cmd == "up" {
			actionErr = topo.Up(ctx, client)
		} else if cmd == "down" {
			actionErr = topo.Down(ctx, client)
		} else {
			st, err := topo.Status(ctx, client)
			if err != nil {
				fmt.Fprintf(os.Stderr, "Status failed: %v\n", err)
				os.Exit(1)
			}
			data, _ := json.MarshalIndent(st, "", "  ")
			fmt.Println(string(data))
			return
		}
		if actionErr != nil {
			fmt.Fprintf(os.Stderr, "%s failed: %v\n", cmd, actionErr)
			os.Exit(1)
		}
		fmt.Printf("Topology %s %s successful\n", name, cmd)
	case "test":
		if len(os.Args) < 3 {
			fmt.Println("Usage: mdb test <topology>")
			os.Exit(1)
		}
		name := os.Args[2]
		if _, err := topology.DefaultRegistry().Get(name); err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
		client, ctx := docker.NewClient(), context.Background()
		cfg := dbclient.Config{
			Name:        name,
			ClusterType: name,
			Container:   defaultContainer(name),
			Executor:    client,
		}
		verifier, err := dbclient.NewVerifier(name, cfg)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Verifier error: %v\n", err)
			os.Exit(1)
		}
		defer verifier.Close()
		health, err := verifier.VerifyCluster(ctx)
		if err != nil && health == nil {
			fmt.Fprintf(os.Stderr, "Verification failed: %v\n", err)
			os.Exit(1)
		}
		data, _ := json.MarshalIndent(health, "", "  ")
		fmt.Println(string(data))
		if health.Status == dbclient.StatusUnhealthy {
			os.Exit(1)
		}
	case "bench":
		if len(os.Args) < 3 {
			fmt.Println("Usage: mdb bench <topology> [--workload <w>] [--threads <n>] [--duration <d>]")
			os.Exit(1)
		}
		name := os.Args[2]
		if _, err := topology.DefaultRegistry().Get(name); err != nil {
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
		fs := flag.NewFlagSet("bench", flag.ExitOnError)
		workload := fs.String("workload", "oltp_read_write", "Sysbench workload")
		threads := fs.Int("threads", 4, "Number of threads")
		duration := fs.Duration("duration", 10*time.Second, "Benchmark duration")
		_ = fs.Parse(os.Args[3:])

		client, ctx := docker.NewClient(), context.Background()
		runner := bench.NewSysbenchRunner(bench.SysbenchConfig{
			Workload:  *workload,
			Container: defaultContainer(name),
			Threads:   *threads,
			Duration:  *duration,
			Executor:  client,
		})
		res, err := runner.Run(ctx)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Benchmark failed: %v\n", err)
			os.Exit(1)
		}
		data, _ := res.ToJSON()
		fmt.Println(data)
	case "report":
		fs := flag.NewFlagSet("report", flag.ExitOnError)
		jsonOut := fs.String("json", "", "Path to export JSON telemetry report")
		htmlOut := fs.String("html", "", "Path to export HTML report")
		_ = fs.Parse(os.Args[2:])

		rep := report.NewReport(version)
		client, ctx := docker.NewClient(), context.Background()

		topos := fs.Args()
		if len(topos) == 0 {
			for _, t := range topology.DefaultRegistry().List() {
				topos = append(topos, t.Name())
			}
		}

		for _, name := range topos {
			cfg := dbclient.Config{
				Name:        name,
				ClusterType: name,
				Container:   defaultContainer(name),
				Executor:    client,
			}
			verifier, err := dbclient.NewVerifier(name, cfg)
			if err != nil {
				continue
			}
			health, _ := verifier.VerifyCluster(ctx)
			if health != nil {
				rep.AddCluster(health)
			}
			_ = verifier.Close()
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

func defaultContainer(topo string) string {
	switch strings.ToLower(topo) {
	case "galera": return "node1"
	case "repli": return "primary"
	case "innodb": return "mysql1"
	case "patroni": return "patroni1"
	case "pgpool": return "pgpool"
	case "mongo", "mongo8": return "mongo1"
	default: return "db"
	}
}

