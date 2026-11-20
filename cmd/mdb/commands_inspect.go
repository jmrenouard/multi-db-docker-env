package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"
	"text/tabwriter"

	"github.com/jmrenouard/multi-db-docker-env/pkg/catalog"
	"github.com/jmrenouard/multi-db-docker-env/pkg/config"
	"github.com/jmrenouard/multi-db-docker-env/pkg/docker"
	"github.com/jmrenouard/multi-db-docker-env/pkg/topology"
)

func loadPasswordWarn(stderr io.Writer) string {
	if _, err := os.Stat(".env"); err != nil && strings.TrimSpace(os.Getenv("DB_ROOT_PASSWORD")) == "" && stderr != nil {
		fmt.Fprintf(stderr, "Warning: .env not found; using default password %q.\n", config.DefaultConfig().RootPassword)
	}
	return loadPassword()
}

func streamCommand(ctx context.Context, extraEnv []string, stdin io.Reader, stdout, stderr io.Writer, name string, args ...string) error {
	cmd := exec.CommandContext(ctx, name, args...)
	if len(extraEnv) > 0 {
		cmd.Env = append(os.Environ(), extraEnv...)
	}
	cmd.Stdin, cmd.Stdout, cmd.Stderr = stdin, stdout, stderr
	return cmd.Run()
}

func renderStatusTable(w io.Writer, items []docker.ContainerStatus) {
	if len(items) == 0 {
		fmt.Fprintln(w, "No active containers found.")
		return
	}
	tw := tabwriter.NewWriter(w, 0, 4, 2, ' ', 0)
	fmt.Fprintln(tw, "NAME\tSERVICE\tSTATE\tSTATUS\tPORTS\tCOMPOSE_FILE")
	for _, it := range items {
		p := it.Ports
		if p == "" {
			p = "-"
		}
		fmt.Fprintf(tw, "%s\t%s\t%s\t%s\t%s\t%s\n", it.Name, it.Service, it.State, it.Status, p, it.File)
	}
	_ = tw.Flush()
}

func writeStatusItems(w io.Writer, items []docker.ContainerStatus, asJSON bool) error {
	if !asJSON {
		renderStatusTable(w, items)
		return nil
	}
	if items == nil {
		items = []docker.ContainerStatus{}
	}
	b, err := json.MarshalIndent(items, "", "  ")
	if err != nil {
		return err
	}
	fmt.Fprintln(w, string(b))
	return nil
}

func pickPrimaryContainer(items []docker.ContainerStatus) (docker.ContainerStatus, bool) {
	var fb *docker.ContainerStatus
	for i := range items {
		it := items[i]
		if !strings.EqualFold(it.State, "running") && !strings.HasPrefix(strings.ToLower(it.Status), "up") {
			continue
		}
		if fb == nil {
			fb = &it
		}
		if it.Service != "traefik" && !strings.HasPrefix(it.Service, "haproxy") && !strings.HasPrefix(it.Service, "etcd") {
			return it, true
		}
	}
	if fb != nil {
		return *fb, true
	}
	return docker.ContainerStatus{}, false
}

func runStatusCmd(ctx context.Context, client *docker.Client, cat *catalog.Catalog, args []string, stdout io.Writer) error {
	fs := flag.NewFlagSet("status", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	jsonF := fs.Bool("json", false, "")
	flags, pos := splitFlagsAndArgs(args, map[string]bool{"json": true})
	if err := fs.Parse(flags); err != nil {
		return err
	}
	target := ""
	if len(pos) > 0 {
		target = pos[0]
	}
	if target != "" && !strings.EqualFold(target, "all") {
		if topo, err := topology.DefaultRegistry().Get(target); err == nil {
			st, err := topo.Status(ctx, client)
			if err != nil {
				return err
			}
			b, _ := json.MarshalIndent(st, "", "  ")
			fmt.Fprintln(stdout, string(b))
			return nil
		}
		if env, ok := cat.Lookup(target); ok && env.Category == catalog.CategoryStandalone {
			items, err := client.ComposePSStatus(ctx, env.ComposeFiles)
			if err != nil {
				return err
			}
			var filtered []docker.ContainerStatus
			for _, it := range items {
				if it.Service == env.ID || it.Service == "traefik" {
					filtered = append(filtered, it)
				}
			}
			return writeStatusItems(stdout, filtered, *jsonF)
		}
		return fmt.Errorf("unknown environment: %s", target)
	}
	items, err := client.ComposePSStatusAll(ctx, nil)
	if err != nil && len(items) == 0 {
		return err
	}
	return writeStatusItems(stdout, items, *jsonF)
}

func runInfoCmd(ctx context.Context, client *docker.Client, stdout io.Writer) error {
	items, err := client.ComposePSStatusAll(ctx, nil)
	if err != nil && len(items) == 0 {
		return err
	}
	primary, ok := pickPrimaryContainer(items)
	if !ok {
		fmt.Fprintln(stdout, "No active database service is running.")
		return nil
	}
	fmt.Fprintf(stdout, "Active service: %s (container: %s, compose: %s)\n\n", primary.Service, primary.Name, primary.File)
	renderStatusTable(stdout, items)
	if logs, err := client.Logs(ctx, primary.Name, 10); err == nil && strings.TrimSpace(logs) != "" {
		fmt.Fprintf(stdout, "\nRecent logs (%s):\n%s\n", primary.Name, strings.TrimSpace(logs))
	}
	return nil
}

func buildLogsArgs(ctx context.Context, client *docker.Client, cat *catalog.Catalog, args []string) ([]string, error) {
	fs := flag.NewFlagSet("logs", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	tail := fs.Int("tail", 100, "")
	follow := fs.Bool("f", false, "")
	flags, pos := splitFlagsAndArgs(args, map[string]bool{"f": true})
	if err := fs.Parse(flags); err != nil {
		return nil, err
	}
	tailArg := fmt.Sprintf("%d", *tail)
	composeLogs := func(files, profiles, svcs []string) []string {
		cArgs := []string{"compose"}
		for _, f := range files {
			cArgs = append(cArgs, "-f", f)
		}
		for _, p := range profiles {
			cArgs = append(cArgs, "--profile", p)
		}
		cArgs = append(cArgs, "logs", "--tail", tailArg)
		if *follow {
			cArgs = append(cArgs, "-f")
		}
		return append(cArgs, svcs...)
	}
	target := ""
	if len(pos) > 0 {
		target = pos[0]
		if env, ok := cat.Lookup(target); ok {
			if env.Category == catalog.CategoryStandalone {
				return composeLogs(env.ComposeFiles, []string{env.Profile}, []string{env.ID}), nil
			}
			return composeLogs(env.ComposeFiles, nil, nil), nil
		}
		if topo, err := topology.DefaultRegistry().Get(target); err == nil {
			var profiles []string
			if target == "standalone" {
				profiles = []string{"*"}
			}
			return composeLogs(topo.ComposeFiles(), profiles, nil), nil
		}
	} else {
		items, err := client.ComposePSStatusAll(ctx, nil)
		if err != nil && len(items) == 0 {
			return nil, err
		}
		primary, ok := pickPrimaryContainer(items)
		if !ok {
			return nil, errors.New("no running container found")
		}
		target = primary.Name
	}
	dArgs := []string{"logs", "--tail", tailArg}
	if *follow {
		dArgs = append(dArgs, "-f")
	}
	return append(dArgs, target), nil
}

func runLogsCmd(ctx context.Context, client *docker.Client, cat *catalog.Catalog, args []string) error {
	dArgs, err := buildLogsArgs(ctx, client, cat, args)
	if err != nil {
		return err
	}
	return streamCommand(ctx, nil, nil, os.Stdout, os.Stderr, "docker", dArgs...)
}
