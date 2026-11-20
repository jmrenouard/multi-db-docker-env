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

// ContainerStatus describes a Compose container's state and endpoints.
type ContainerStatus struct {
	Name    string `json:"name"`
	Service string `json:"service"`
	State   string `json:"state"`
	Status  string `json:"status"`
	Ports   string `json:"ports,omitempty"`
	File    string `json:"file,omitempty"`
}

func composeArgs(files []string, sub string, extra ...string) []string {
	return composeProfileArgs(files, nil, sub, extra...)
}

func composeProfileArgs(files, profiles []string, sub string, extra ...string) []string {
	args := []string{"compose"}
	for _, f := range files {
		args = append(args, "-f", f)
	}
	for _, p := range profiles {
		if p != "" {
			args = append(args, "--profile", p)
		}
	}
	return append(append(args, sub), extra...)
}

func (c *Client) ComposeUp(ctx context.Context, files []string, env map[string]string, detach bool, services ...string) error {
	return c.ComposeUpProfiles(ctx, files, nil, env, detach, services...)
}

// ComposeUpProfiles runs `docker compose up` with optional profiles, env vars, and services.
func (c *Client) ComposeUpProfiles(ctx context.Context, files, profiles []string, env map[string]string, detach bool, services ...string) error {
	args := []string{"compose"}
	for _, f := range files {
		args = append(args, "-f", f)
	}
	for _, p := range profiles {
		if p != "" {
			args = append(args, "--profile", p)
		}
	}
	for _, k := range slices.Sorted(maps.Keys(env)) {
		args = append(args, "--env", fmt.Sprintf("%s=%s", k, env[k]))
	}
	args = append(args, "up")
	if detach {
		args = append(args, "-d")
	}
	_, stderr, code, err := c.runner.Run(ctx, "docker", append(args, services...)...)
	if err != nil || code != 0 {
		return fmt.Errorf("docker compose up failed (%d): %s: %w", code, strings.TrimSpace(string(stderr)), err)
	}
	return nil
}

func (c *Client) ComposeDown(ctx context.Context, files []string, removeVolumes bool) error {
	return c.ComposeDownProfiles(ctx, files, nil, removeVolumes)
}

// ComposeDownProfiles runs `docker compose down` with optional profile flags.
func (c *Client) ComposeDownProfiles(ctx context.Context, files, profiles []string, removeVolumes bool) error {
	var extra []string
	if removeVolumes {
		extra = []string{"-v"}
	}
	_, stderr, code, err := c.runner.Run(ctx, "docker", composeProfileArgs(files, profiles, "down", extra...)...)
	if err != nil || code != 0 {
		return fmt.Errorf("docker compose down failed (%d): %s: %w", code, strings.TrimSpace(string(stderr)), err)
	}
	return nil
}

func (c *Client) ComposePS(ctx context.Context, files []string) ([]string, error) {
	out, _, code, err := c.runner.Run(ctx, "docker", composeArgs(files, "ps", "--format", "{{.Name}}")...)
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

// ProjectName returns COMPOSE_PROJECT_NAME or the current directory's base name.
func ProjectName() string {
	if v := strings.TrimSpace(os.Getenv("COMPOSE_PROJECT_NAME")); v != "" {
		return v
	}
	if wd, err := os.Getwd(); err == nil {
		if base := filepath.Base(wd); base != "" && base != "." && base != string(filepath.Separator) {
			return base
		}
	}
	return "multi-db-docker-env"
}

// DiscoverComposeFiles returns docker-compose.yml (if present) and all docker-compose-*.yml files on disk.
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

// ComposeDownAll stops and cleans containers across all given (or discovered) compose files and project labels.
func (c *Client) ComposeDownAll(ctx context.Context, filesList [][]string, projectName string) error {
	if len(filesList) == 0 {
		filesList = DiscoverComposeFiles()
	}
	var firstErr error
	for _, files := range filesList {
		if len(files) == 0 {
			continue
		}
		_, stderr, code, err := c.runner.Run(ctx, "docker", composeProfileArgs(files, profilesFor(files), "down", "-v", "--remove-orphans")...)
		if (err != nil || code != 0) && firstErr == nil {
			firstErr = fmt.Errorf("docker compose down failed (%d): %s: %w", code, strings.TrimSpace(string(stderr)), err)
		}
	}
	if projectName != "" {
		for _, lbl := range []string{projectName, strings.ToLower(projectName)} {
			out, _, code, err := c.runner.Run(ctx, "docker", "ps", "-aq", "--filter", "label=com.docker.compose.project="+lbl)
			if err == nil && code == 0 {
				if ids := splitLines(out); len(ids) > 0 {
					_, _, _, _ = c.runner.Run(ctx, "docker", append([]string{"rm", "-f"}, ids...)...)
				}
			}
			if lbl == strings.ToLower(projectName) {
				break
			}
		}
	}
	return firstErr
}

// ComposePSStatus inspects container statuses for the given compose files.
func (c *Client) ComposePSStatus(ctx context.Context, files []string) ([]ContainerStatus, error) {
	out, _, code, err := c.runner.Run(ctx, "docker", composeProfileArgs(files, profilesFor(files), "ps", "--format", "{{.Name}}\t{{.Service}}\t{{.State}}\t{{.Status}}\t{{.Ports}}")...)
	if err != nil || code != 0 {
		return nil, fmt.Errorf("docker compose ps failed (%d): %w", code, err)
	}
	fileLabel := strings.Join(files, ",")
	var res []ContainerStatus
	for _, line := range splitLines(out) {
		p := strings.SplitN(line, "\t", 5)
		for len(p) < 5 {
			p = append(p, "")
		}
		res = append(res, ContainerStatus{Name: p[0], Service: p[1], State: p[2], Status: p[3], Ports: p[4], File: fileLabel})
	}
	return res, nil
}

// ComposePSStatusAll inspects containers across all given (or discovered) compose files.
func (c *Client) ComposePSStatusAll(ctx context.Context, filesList [][]string) ([]ContainerStatus, error) {
	if len(filesList) == 0 {
		filesList = DiscoverComposeFiles()
	}
	seen := make(map[string]bool)
	var all []ContainerStatus
	for _, files := range filesList {
		if len(files) == 0 {
			continue
		}
		items, err := c.ComposePSStatus(ctx, files)
		if err != nil {
			continue
		}
		for _, item := range items {
			if !seen[item.Name] {
				seen[item.Name] = true
				all = append(all, item)
			}
		}
	}
	return all, nil
}
