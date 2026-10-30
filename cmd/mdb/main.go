package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"

	"github.com/jmrenouard/multi-db-docker-env/pkg/config"
)

var version = "1.3.33"

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: mdb <version|config> [options]")
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
	default:
		fmt.Fprintf(os.Stderr, "Unknown command: %s\n", os.Args[1])
		os.Exit(1)
	}
}
