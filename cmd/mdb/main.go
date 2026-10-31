package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"strings"

	"github.com/jmrenouard/multi-db-docker-env/pkg/config"
	"github.com/jmrenouard/multi-db-docker-env/pkg/docker"
	"github.com/jmrenouard/multi-db-docker-env/pkg/pki"
	"github.com/jmrenouard/multi-db-docker-env/pkg/topology"
)

var version = "1.3.37"

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: mdb <version|config|pki|up|down|status|topologies> [options]")
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
	default:
		fmt.Fprintf(os.Stderr, "Unknown command: %s\n", os.Args[1])
		os.Exit(1)
	}
}
