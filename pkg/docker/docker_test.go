package docker

import (
	"context"
	"errors"
	"strings"
	"testing"
)

func TestClient_Core(t *testing.T) {
	ctx := context.Background()
	m := &MockCommandRunner{Output: []byte("c1\nc2\n")}
	c := NewClientWithRunner(m)

	if n, err := c.PS(ctx, ""); err != nil || len(n) != 2 || n[0] != "c1" {
		t.Fatalf("PS: %v, %v", n, err)
	}
	m.Output = []byte("g1\n")
	if n, err := c.PS(ctx, "name=g"); err != nil || len(n) != 1 || !strings.Contains(strings.Join(m.Calls[1], " "), "--filter name=g") {
		t.Fatalf("PS filter: %v, %v", n, err)
	}
	m.Err, m.ExitCode = errors.New("err"), 1
	if _, err := c.PS(ctx, ""); err == nil {
		t.Fatal("expected err")
	}

	m.Err, m.ExitCode, m.Output = nil, 0, []byte("pong\n")
	if out, err := c.Exec(ctx, "c1", []string{"K=V"}, "ping"); err != nil || strings.TrimSpace(out) != "pong" || !strings.Contains(strings.Join(m.Calls[3], " "), "exec -e K=V c1 ping") {
		t.Fatalf("exec: %s, %v", out, err)
	}
	m.Err, m.ExitCode, m.Stderr = errors.New("err"), 1, []byte("fail")
	if _, err := c.Exec(ctx, "c1", nil, "ls"); err == nil {
		t.Fatal("expected err")
	}

	m.Err, m.ExitCode, m.Output, m.Stderr = nil, 0, []byte("stdout\n"), nil
	if logs, err := c.Logs(ctx, "c1", 10); err != nil || !strings.Contains(logs, "stdout") || !strings.Contains(strings.Join(m.Calls[5], " "), "logs --tail 10 c1") {
		t.Fatalf("logs: %s, %v", logs, err)
	}
	m.Output, m.Stderr = nil, []byte("stderr\n")
	if logs, err := c.Logs(ctx, "c1", 0); err != nil || !strings.Contains(logs, "stderr") {
		t.Fatalf("stderr logs: %s, %v", logs, err)
	}
	m.Err, m.ExitCode = errors.New("err"), 1
	if _, err := c.Logs(ctx, "c1", 0); err == nil {
		t.Fatal("expected err")
	}

	m.Err, m.ExitCode, m.Output = nil, 0, []byte("c1\n")
	if ok, err := c.IsRunning(ctx, "c1"); err != nil || !ok {
		t.Fatalf("running: %v, %v", ok, err)
	}
	m.Output = []byte("")
	if ok, err := c.IsRunning(ctx, "c1"); err != nil || ok {
		t.Fatalf("not running: %v, %v", ok, err)
	}
	m.Err, m.ExitCode = errors.New("err"), 1
	if _, err := c.IsRunning(ctx, "c1"); err == nil {
		t.Fatal("expected err")
	}
}

func TestClient_Compose(t *testing.T) {
	ctx := context.Background()
	m := &MockCommandRunner{Output: []byte("s1\ns2\n")}
	c := NewClientWithRunner(m)

	if err := c.ComposeUp(ctx, []string{"f1.yml"}, map[string]string{"K": "V"}, true, "s1"); err != nil || !strings.Contains(strings.Join(m.Calls[0], " "), "compose -f f1.yml --env K=V up -d s1") {
		t.Fatalf("compose up: %v", err)
	}
	if err := c.ComposeDown(ctx, []string{"f1.yml"}, true); err != nil || !strings.Contains(strings.Join(m.Calls[1], " "), "compose -f f1.yml down -v") {
		t.Fatalf("compose down: %v", err)
	}
	_ = c.ComposeDown(ctx, []string{"f1.yml"}, false)
	if strings.Contains(strings.Join(m.Calls[2], " "), "-v") {
		t.Fatal("unexpected -v")
	}
	if names, err := c.ComposePS(ctx, []string{"f.yml"}); err != nil || len(names) != 2 || names[0] != "s1" {
		t.Fatalf("compose ps: %v, %v", names, err)
	}
	m.Output = []byte("out")
	if logs, err := c.ComposeLogs(ctx, []string{"f.yml"}, 50, "s1"); err != nil || logs != "out" || !strings.Contains(strings.Join(m.Calls[4], " "), "compose -f f.yml logs --tail 50 s1") {
		t.Fatalf("compose logs: %s, %v", logs, err)
	}
	m.Output, m.Stderr = nil, []byte("errlog")
	if logs, _ := c.ComposeLogs(ctx, nil, 0); logs != "errlog" {
		t.Fatalf("expected errlog: %s", logs)
	}

	m.Err, m.ExitCode, m.Stderr = errors.New("err"), 1, []byte("err")
	if err := c.ComposeUp(ctx, nil, nil, false); err == nil {
		t.Fatal("expected up err")
	}
	if err := c.ComposeDown(ctx, nil, false); err == nil {
		t.Fatal("expected down err")
	}
	if _, err := c.ComposePS(ctx, nil); err == nil {
		t.Fatal("expected ps err")
	}
	if _, err := c.ComposeLogs(ctx, nil, 0); err == nil {
		t.Fatal("expected logs err")
	}
}

func TestRealCommandRunner(t *testing.T) {
	ctx := context.Background()
	r := &RealCommandRunner{}
	if out, _, code, err := r.Run(ctx, "go", "env", "GOROOT"); err != nil || code != 0 || len(out) == 0 {
		t.Fatalf("RealCommandRunner: %v", err)
	}
	if combined, err := r.RunCombined(ctx, "go", "env", "GOROOT"); err != nil || len(combined) == 0 {
		t.Fatalf("RunCombined: %v", err)
	}
	if NewClient().Runner() == nil {
		t.Fatal("nil runner")
	}
	cleanArgs, envVars := extractComposeEnv("docker", []string{"compose", "-f", "f1.yml", "--env", "K=V", "up", "-d"})
	if len(envVars) != 1 || envVars[0] != "K=V" || strings.Contains(strings.Join(cleanArgs, " "), "--env") {
		t.Fatalf("extractComposeEnv: args=%v env=%v", cleanArgs, envVars)
	}
}
