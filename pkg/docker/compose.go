package docker

import (
	"context"
	"fmt"
	"maps"
	"os"
	"path/filepath"
	"slices"
	"strings"
)

func composeArgs(files []string, sub string, extra ...string) []string {
	args := []string{"compose"}
	for _, f := range files {
		args = append(args, "-f", f)
	}
	return append(append(args, sub), extra...)
}

func (c *Client) ComposeUp(ctx context.Context, files []string, env map[string]string, detach bool, services ...string) error {
	return c.ComposeUpProfiles(ctx, files, nil, env, detach, services...)
}

func (c *Client) ComposeDown(ctx context.Context, files []string, removeVolumes bool) error {
	var extra []string
	if removeVolumes {
		extra = []string{"-v"}
	}
	_, stderr, code, err := c.runner.Run(ctx, "docker", composeArgs(files, "down", extra...)...)
	if err != nil || code != 0 {
		return fmt.Errorf("docker compose down failed (%d): %s: %w", code, strings.TrimSpace(string(stderr)), err)
	}
	return nil
}

func (c *Client) ComposePS(ctx context.Context, files []string) ([]string, error) {
	out, _, code, err := c.runner.Run(ctx, "docker", append(composePrefix(files, profilesFor(files)), "ps", "--orphans=false", "--format", "{{.Name}}")...)
	if err != nil || code != 0 {
		return nil, fmt.Errorf("docker compose ps failed (%d): %w", code, err)
	}
	return splitLines(out), nil
}

func (c *Client) ComposeLogs(ctx context.Context, files []string, tail int, services ...string) (string, error) {
	var extra []string
	if tail > 0 {
		extra = []string{"--tail", fmt.Sprintf("%d", tail)}
	}
	out, stderr, code, err := c.runner.Run(ctx, "docker", composeArgs(files, "logs", append(extra, services...)...)...)
	if err != nil || code != 0 {
		return "", fmt.Errorf("docker compose logs failed (%d): %w", code, err)
	}
	if len(out) > 0 {
		return string(out), nil
	}
	return string(stderr), nil
}

// ContainerStatus describes a Compose container's state and endpoints.
type ContainerStatus struct {
	Name    string `json:"name"`
	Service string `json:"service"`
	State   string `json:"state"`
	Status  string `json:"status"`
	Ports   string `json:"ports,omitempty"`
	File    string `json:"file,omitempty"`
}

func composePrefix(files, profiles []string) []string {
	args := []string{"compose"}
	for _, f := range files {
		args = append(args, "-f", f)
	}
	for _, p := range profiles {
		if p != "" {
			args = append(args, "--profile", p)
		}
	}
	return args
}

func (c *Client) runCompose(ctx context.Context, env []string, sub string, args []string) error {
	if _, se, code, err := c.RunWithEnv(ctx, env, "docker", args...); err != nil || code != 0 {
		return fmt.Errorf("docker compose %s failed (%d): %s: %w", sub, code, strings.TrimSpace(string(se)), err)
	}
	return nil
}

// ComposeUpProfiles runs `docker compose up` with optional profiles, env vars, and services.
func (c *Client) ComposeUpProfiles(ctx context.Context, files, profiles []string, env map[string]string, detach bool, services ...string) error {
	args := composePrefix(files, profiles)
	args = append(args, "up")
	if detach {
		args = append(args, "-d")
	}
	envList := make([]string, 0, len(env))
	for _, k := range slices.Sorted(maps.Keys(env)) {
		envList = append(envList, k+"="+env[k])
	}
	return c.runCompose(ctx, envList, "up", append(args, services...))
}

// ComposeDownProfiles runs `docker compose down` with optional profile flags.
func (c *Client) ComposeDownProfiles(ctx context.Context, files, profiles []string, removeVolumes bool) error {
	args := append(composePrefix(files, profiles), "down")
	if removeVolumes {
		args = append(args, "-v")
	}
	return c.runCompose(ctx, nil, "down", args)
}

// ProjectName returns COMPOSE_PROJECT_NAME or the current directory's base name.
func ProjectName() string {
	if v := strings.TrimSpace(os.Getenv("COMPOSE_PROJECT_NAME")); v != "" {
		return v
	}
	if wd, err := os.Getwd(); err == nil {
		if b := filepath.Base(wd); b != "" && b != "." && b != string(filepath.Separator) {
			return b
		}
	}
	return "multi-db-docker-env"
}

// DiscoverComposeFiles lists docker-compose.yml and docker-compose-*.yml on disk.
func DiscoverComposeFiles() [][]string {
	var list [][]string
	if _, err := os.Stat("docker-compose.yml"); err == nil {
		list = append(list, []string{"docker-compose.yml"})
	}
	if extras, err := filepath.Glob("docker-compose-*.yml"); err == nil {
		for _, f := range extras {
			list = append(list, []string{f})
		}
	}
	return list
}

func profilesFor(files []string) []string {
	if slices.ContainsFunc(files, func(f string) bool { return filepath.Base(f) == "docker-compose.yml" }) {
		return []string{"*"}
	}
	return nil
}

// ComposeDownAll stops containers across compose files and project labels.
func (c *Client) ComposeDownAll(ctx context.Context, filesList [][]string, projectName string) error {
	if len(filesList) == 0 {
		filesList = DiscoverComposeFiles()
	}
	var firstErr error
	rec := func(err error) {
		if firstErr == nil {
			firstErr = err
		}
	}
	for _, files := range filesList {
		if len(files) > 0 {
			rec(c.runCompose(ctx, nil, "down", append(composePrefix(files, profilesFor(files)), "down", "-v", "--remove-orphans")))
		}
	}
	if projectName != "" {
		lbls := []string{projectName}
		if low := strings.ToLower(projectName); low != projectName {
			lbls = append(lbls, low)
		}
		for _, lbl := range lbls {
			out, se, code, err := c.runner.Run(ctx, "docker", "ps", "-aq", "--filter", "label=com.docker.compose.project="+lbl)
			if err != nil || code != 0 {
				rec(fmt.Errorf("docker ps failed (%d): %s: %w", code, strings.TrimSpace(string(se)), err))
			} else if ids := splitLines(out); len(ids) > 0 {
				if _, re, rc, rErr := c.runner.Run(ctx, "docker", append([]string{"rm", "-f"}, ids...)...); rErr != nil || rc != 0 {
					rec(fmt.Errorf("docker rm failed (%d): %s: %w", rc, strings.TrimSpace(string(re)), rErr))
				}
			}
		}
	}
	return firstErr
}

// ComposePSStatus inspects container statuses for the given compose files.
func (c *Client) ComposePSStatus(ctx context.Context, files []string) ([]ContainerStatus, error) {
	out, _, code, err := c.runner.Run(ctx, "docker", append(composePrefix(files, profilesFor(files)), "ps", "--orphans=false", "--format", "{{.Name}}\t{{.Service}}\t{{.State}}\t{{.Status}}\t{{.Ports}}")...)
	if err != nil || code != 0 {
		return nil, fmt.Errorf("docker compose ps failed (%d): %w", code, err)
	}
	lbl := strings.Join(files, ",")
	var res []ContainerStatus
	for _, line := range splitLines(out) {
		var p [5]string
		copy(p[:], strings.SplitN(line, "\t", 5))
		res = append(res, ContainerStatus{Name: p[0], Service: p[1], State: p[2], Status: p[3], Ports: p[4], File: lbl})
	}
	return res, nil
}

// ComposePSStatusAll inspects containers across compose files.
func (c *Client) ComposePSStatusAll(ctx context.Context, filesList [][]string) ([]ContainerStatus, error) {
	if len(filesList) == 0 {
		filesList = DiscoverComposeFiles()
	}
	seen, all := make(map[string]bool), []ContainerStatus(nil)
	var firstErr error
	for _, files := range filesList {
		if len(files) == 0 {
			continue
		}
		items, err := c.ComposePSStatus(ctx, files)
		if err != nil && firstErr == nil {
			firstErr = err
		}
		for _, item := range items {
			if !seen[item.Name] {
				seen[item.Name] = true
				all = append(all, item)
			}
		}
	}
	return all, firstErr
}
