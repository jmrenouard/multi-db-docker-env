package main

import (
	"context"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/jmrenouard/multi-db-docker-env/pkg/catalog"
	"github.com/jmrenouard/multi-db-docker-env/pkg/config"
	"github.com/jmrenouard/multi-db-docker-env/pkg/docker"
	"github.com/jmrenouard/multi-db-docker-env/pkg/topology"
)

func printUsage(w io.Writer) {
	fmt.Fprint(w, `Usage: mdb <command> [options]

Lifecycle:
  up <env> | start [env]   Start profile or cluster (rejects EOL; default: mariadb114)
  down [env|all] | stop    Stop specified env or all active containers
  status [env|all] | info  Show active containers, status, and recent logs
  logs [env|svc] [flags]   Stream or tail logs (--tail N, -f)

Client, Diagnostics & Operations:
  catalog [flags]          List environments (--category, --engine, --eol, --all, --json)
                           Aliases: list, envs, environments, topologies
  client [env] | mycnf     Open DB shell or backup/write ~/.my.cnf (0600)
  doctor | config | pki | test | bench | report | version | help
`)
}

func hasComposeFile(name string) bool {
	for i, dir := 0, "."; i < 5; i, dir = i+1, filepath.Join("..", dir) {
		if _, err := os.Stat(filepath.Join(dir, name)); err == nil {
			return true
		}
		if _, err := os.Stat(filepath.Join(dir, "go.mod")); err == nil {
			return false
		}
	}
	return false
}

func activeCatalog() *catalog.Catalog {
	return catalog.NewCatalog(hasComposeFile("docker-compose-yt-cluster.yml"))
}

func resolveDefaultEnv() string {
	if v := strings.TrimSpace(os.Getenv("DEFAULT_SERVICE")); v != "" {
		return v
	}
	if f, err := os.Open(".env"); err == nil {
		defer f.Close()
		if m, err := config.ParseEnvReader(f); err == nil {
			for _, k := range []string{"DEFAULT_SERVICE", "DEFAULT_DB"} {
				if v := strings.TrimSpace(m[k]); v != "" {
					return v
				}
			}
		}
	}
	return "mariadb114"
}

func splitFlagsAndArgs(args []string, boolFlags map[string]bool) (flags, pos []string) {
	for i := 0; i < len(args); i++ {
		if a := args[i]; strings.HasPrefix(a, "-") && a != "-" {
			flags = append(flags, a)
			if name := strings.TrimLeft(a, "-"); !strings.Contains(name, "=") && !boolFlags[name] && i+1 < len(args) {
				i++
				flags = append(flags, args[i])
			}
		} else {
			pos = append(pos, a)
		}
	}
	return flags, pos
}

func checkEOLError(env catalog.Environment) error {
	return fmt.Errorf("decommissioned environment %q (%s) reached EOL on %s; use: %s",
		env.ID, env.Description, env.EOLDate, env.Replacement)
}

func runCatalogCmd(args []string, cat *catalog.Catalog, stdout io.Writer) error {
	fs := flag.NewFlagSet("catalog", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	catF := fs.String("category", "", "")
	engF := fs.String("engine", "", "")
	eolF := fs.Bool("eol", false, "")
	allF := fs.Bool("all", false, "")
	jsonF := fs.Bool("json", false, "")
	flags, _ := splitFlagsAndArgs(args, map[string]bool{"eol": true, "all": true, "json": true})
	if err := fs.Parse(flags); err != nil {
		return err
	}
	if c := strings.TrimSpace(*catF); c != "" && !strings.EqualFold(c, catalog.CategoryStandalone) && !strings.EqualFold(c, catalog.CategoryCluster) {
		return fmt.Errorf("invalid category %q (expected standalone or cluster)", c)
	}
	envs := cat.Filter(*catF, *engF, !*eolF || *allF, *eolF || *allF)
	if *jsonF {
		out, err := catalog.RenderJSON(envs)
		if err != nil {
			return err
		}
		fmt.Fprintln(stdout, out)
		return nil
	}
	fmt.Fprint(stdout, catalog.RenderTable(envs))
	return nil
}

func runUpCmd(ctx context.Context, client *docker.Client, cat *catalog.Catalog, target string) error {
	if env, ok := cat.Lookup(target); ok {
		if env.Status == catalog.StatusEOL {
			return checkEOLError(env)
		}
		if env.Category == catalog.CategoryStandalone {
			t, err := topology.DefaultRegistry().Get("standalone")
			if err != nil {
				return err
			}
			if st, ok := t.(*topology.StandaloneTopology); ok {
				return st.UpProfile(ctx, client, env.ID)
			}
			return t.Up(ctx, client)
		}
	}
	topo, err := topology.DefaultRegistry().Get(target)
	if err != nil {
		return err
	}
	return topo.Up(ctx, client)
}

func runDownCmd(ctx context.Context, client *docker.Client, cat *catalog.Catalog, target string) error {
	t := strings.TrimSpace(target)
	if t == "" || strings.EqualFold(t, "all") {
		return client.ComposeDownAll(ctx, nil, docker.ProjectName())
	}
	if env, ok := cat.Lookup(t); ok && env.Category == catalog.CategoryStandalone {
		return client.ComposeDownProfiles(ctx, env.ComposeFiles, []string{env.Profile}, true)
	}
	topo, err := topology.DefaultRegistry().Get(t)
	if err != nil {
		return err
	}
	return topo.Down(ctx, client)
}
