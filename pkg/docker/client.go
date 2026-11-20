package docker

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"sync"
)

type CommandRunner interface {
	Run(ctx context.Context, name string, args ...string) ([]byte, []byte, int, error)
	RunCombined(ctx context.Context, name string, args ...string) ([]byte, error)
}

// EnvCommandRunner optionally executes commands with extra environment variables.
type EnvCommandRunner interface {
	RunWithEnv(ctx context.Context, env []string, name string, args ...string) ([]byte, []byte, int, error)
}

type RealCommandRunner struct{}

func extractComposeEnv(name string, args []string) ([]string, []string) {
	if name != "docker" || len(args) == 0 || args[0] != "compose" {
		return args, nil
	}
	filtered := make([]string, 0, len(args))
	var envVars []string
	for i := 0; i < len(args); i++ {
		if args[i] == "--env" && i+1 < len(args) {
			envVars = append(envVars, args[i+1])
			i++
		} else {
			filtered = append(filtered, args[i])
		}
	}
	return filtered, envVars
}

func (r *RealCommandRunner) RunWithEnv(ctx context.Context, env []string, name string, args ...string) ([]byte, []byte, int, error) {
	cleanArgs, envVars := extractComposeEnv(name, args)
	cmd := exec.CommandContext(ctx, name, cleanArgs...)
	if merged := append(envVars, env...); len(merged) > 0 {
		cmd.Env = append(os.Environ(), merged...)
	}
	var stdout, stderr bytes.Buffer
	cmd.Stdout, cmd.Stderr = &stdout, &stderr
	err := cmd.Run()
	code := 0
	if cmd.ProcessState != nil {
		code = cmd.ProcessState.ExitCode()
	} else if err != nil {
		code = 1
	}
	return stdout.Bytes(), stderr.Bytes(), code, err
}

func (r *RealCommandRunner) Run(ctx context.Context, name string, args ...string) ([]byte, []byte, int, error) {
	return r.RunWithEnv(ctx, nil, name, args...)
}

func (r *RealCommandRunner) RunCombined(ctx context.Context, name string, args ...string) ([]byte, error) {
	cleanArgs, envVars := extractComposeEnv(name, args)
	cmd := exec.CommandContext(ctx, name, cleanArgs...)
	if len(envVars) > 0 {
		cmd.Env = append(os.Environ(), envVars...)
	}
	return cmd.CombinedOutput()
}

type MockCommandRunner struct {
	mu       sync.Mutex
	Calls    [][]string
	EnvCalls [][]string
	Output   []byte
	Stderr   []byte
	ExitCode int
	Err      error
	Custom   func(ctx context.Context, name string, args ...string) ([]byte, []byte, int, error)
}

func (m *MockCommandRunner) Run(ctx context.Context, name string, args ...string) ([]byte, []byte, int, error) {
	m.mu.Lock()
	m.Calls = append(m.Calls, append([]string{name}, args...))
	m.mu.Unlock()
	if m.Custom != nil {
		return m.Custom(ctx, name, args...)
	}
	return m.Output, m.Stderr, m.ExitCode, m.Err
}

func (m *MockCommandRunner) RunWithEnv(ctx context.Context, env []string, name string, args ...string) ([]byte, []byte, int, error) {
	if len(env) > 0 {
		m.mu.Lock()
		m.EnvCalls = append(m.EnvCalls, append([]string(nil), env...))
		m.mu.Unlock()
	}
	return m.Run(ctx, name, args...)
}

func (m *MockCommandRunner) RunCombined(ctx context.Context, name string, args ...string) ([]byte, error) {
	out, stderr, _, err := m.Run(ctx, name, args...)
	if err != nil {
		return append(out, stderr...), err
	}
	return out, nil
}

type Client struct{ runner CommandRunner }

func NewClient() *Client                          { return &Client{runner: &RealCommandRunner{}} }
func NewClientWithRunner(r CommandRunner) *Client { return &Client{runner: r} }
func (c *Client) Runner() CommandRunner           { return c.runner }

// RunWithEnv runs a command with optional extra environment variables.
func (c *Client) RunWithEnv(ctx context.Context, env []string, name string, args ...string) ([]byte, []byte, int, error) {
	if er, ok := c.runner.(EnvCommandRunner); ok {
		return er.RunWithEnv(ctx, env, name, args...)
	}
	return c.runner.Run(ctx, name, args...)
}

// ImageExists checks whether a Docker image tag exists locally.
func (c *Client) ImageExists(ctx context.Context, tag string) (bool, error) {
	_, stderr, code, err := c.runner.Run(ctx, "docker", "image", "inspect", tag)
	if err == nil && code == 0 {
		return true, nil
	}
	msg := strings.ToLower(string(stderr))
	if strings.Contains(msg, "cannot connect") || strings.Contains(msg, "daemon") {
		return false, fmt.Errorf("docker daemon error: %s: %w", strings.TrimSpace(string(stderr)), err)
	}
	return false, nil
}

// BuildImage builds a Docker image from dockerfileDir with the given tag.
func (c *Client) BuildImage(ctx context.Context, tag, dockerfileDir string) error {
	if dockerfileDir == "" {
		dockerfileDir = "."
	}
	_, stderr, code, err := c.runner.Run(ctx, "docker", "build", "-t", tag, dockerfileDir)
	if err != nil || code != 0 {
		return fmt.Errorf("docker build %s failed (%d): %s: %w", tag, code, strings.TrimSpace(string(stderr)), err)
	}
	return nil
}

func splitLines(b []byte) []string {
	var res []string
	for _, l := range strings.Split(strings.TrimSpace(string(b)), "\n") {
		if t := strings.TrimSpace(l); t != "" {
			res = append(res, t)
		}
	}
	return res
}

func (c *Client) PS(ctx context.Context, filter string) ([]string, error) {
	args := []string{"ps", "--format", "{{.Names}}"}
	if filter != "" {
		args = append(args, "--filter", filter)
	}
	out, _, code, err := c.runner.Run(ctx, "docker", args...)
	if err != nil || code != 0 {
		return nil, fmt.Errorf("docker ps failed (%d): %w", code, err)
	}
	return splitLines(out), nil
}

func (c *Client) Exec(ctx context.Context, container string, env []string, cmd ...string) (string, error) {
	args := []string{"exec"}
	for _, e := range env {
		args = append(args, "-e", e)
	}
	args = append(append(args, container), cmd...)
	out, stderr, code, err := c.runner.Run(ctx, "docker", args...)
	if err != nil || code != 0 {
		return string(out), fmt.Errorf("docker exec failed (%d): %s: %w", code, strings.TrimSpace(string(stderr)), err)
	}
	return string(out), nil
}

func (c *Client) Logs(ctx context.Context, container string, tail int) (string, error) {
	args := []string{"logs"}
	if tail > 0 {
		args = append(args, "--tail", fmt.Sprintf("%d", tail))
	}
	out, stderr, code, err := c.runner.Run(ctx, "docker", append(args, container)...)
	if err != nil || code != 0 {
		return "", fmt.Errorf("docker logs failed (%d): %w", code, err)
	}
	if len(out) > 0 {
		return string(out), nil
	}
	return string(stderr), nil
}

func (c *Client) IsRunning(ctx context.Context, container string) (bool, error) {
	out, _, code, err := c.runner.Run(ctx, "docker", "ps", "--filter", fmt.Sprintf("name=^/%s$", container), "--filter", "status=running", "--format", "{{.Names}}")
	if err != nil || code != 0 {
		return false, fmt.Errorf("docker ps check failed (%d): %w", code, err)
	}
	for _, l := range splitLines(out) {
		if l == container {
			return true, nil
		}
	}
	return false, nil
}
