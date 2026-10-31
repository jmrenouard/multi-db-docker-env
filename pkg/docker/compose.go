package docker

import (
	"context"
	"fmt"
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
	args := []string{"compose"}
	for _, f := range files {
		args = append(args, "-f", f)
	}
	for k, v := range env {
		args = append(args, "--env", fmt.Sprintf("%s=%s", k, v))
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
