package docker

import (
	"context"
	"errors"
	"os"
	"path/filepath"
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

func TestClient_ProfilesDownAllPSStatusAndImages(t *testing.T) {
	ctx := context.Background()
	m := &MockCommandRunner{Output: []byte("mariadb-11.4\tmariadb114\trunning\tUp 5s\t3306/tcp\n")}
	c := NewClientWithRunner(m)

	if err := c.ComposeUpProfiles(ctx, []string{"docker-compose.yml"}, []string{"traefik", "mariadb114"}, map[string]string{"A": "1"}, true); err != nil {
		t.Fatal(err)
	}
	if cmd0 := strings.Join(m.Calls[0], " "); !strings.Contains(cmd0, "--profile traefik --profile mariadb114 --env A=1 up -d") {
		t.Fatal(cmd0)
	}
	if err := c.ComposeDownProfiles(ctx, []string{"docker-compose.yml"}, []string{"*"}, true); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(strings.Join(m.Calls[1], " "), "--profile * down -v") {
		t.Fatal(m.Calls[1])
	}
	if st, err := c.ComposePSStatusAll(ctx, [][]string{{"docker-compose.yml"}, {"docker-compose-galera.yml"}}); err != nil || len(st) != 1 || st[0].Service != "mariadb114" || st[0].State != "running" {
		t.Fatalf("PSStatusAll: %+v %v", st, err)
	}
	m.Calls = nil
	if err := c.ComposeDownAll(ctx, [][]string{{"docker-compose.yml"}, {"docker-compose-galera.yml"}}, "CustomProj"); err != nil {
		t.Fatal(err)
	}
	if len(m.Calls) < 4 || !strings.Contains(strings.Join(m.Calls[0], " "), "--profile * down -v --remove-orphans") || !strings.Contains(strings.Join(m.Calls[2], " "), "label=com.docker.compose.project=CustomProj") {
		t.Fatal(m.Calls)
	}
	if ok, err := c.ImageExists(ctx, "mariadb_ssh:004"); err != nil || !ok {
		t.Fatal(ok, err)
	}
	m.ExitCode, m.Err, m.Stderr = 1, errors.New("missing"), []byte("No such image")
	if ok, err := c.ImageExists(ctx, "missing:1"); err != nil || ok {
		t.Fatal(ok, err)
	}
	if err := c.BuildImage(ctx, "mariadb_ssh:004", "."); err == nil {
		t.Fatal("expected build error")
	}
	m.ExitCode, m.Err, m.Stderr = 0, nil, nil
	if err := c.BuildImage(ctx, "mariadb_ssh:004", ""); err != nil {
		t.Fatal(err)
	}
	if _, _, _, err := c.RunWithEnv(ctx, []string{"MONGO_NODES=n1 n2"}, "bash", "setup.sh"); err != nil || len(m.EnvCalls) != 1 {
		t.Fatal(err, m.EnvCalls)
	}
	t.Setenv("COMPOSE_PROJECT_NAME", "override-proj")
	if got := ProjectName(); got != "override-proj" {
		t.Fatal(got)
	}
	t.Setenv("COMPOSE_PROJECT_NAME", "")
	wd, _ := os.Getwd()
	defer func() { _ = os.Chdir(wd) }()
	tmp := t.TempDir()
	_ = os.Chdir(tmp)
	if got := ProjectName(); got != filepath.Base(tmp) {
		t.Fatal(got)
	}
	_ = os.WriteFile("docker-compose.yml", []byte("services: {}\n"), 0644)
	_ = os.WriteFile("docker-compose-galera.yml", []byte("services: {}\n"), 0644)
	if files := DiscoverComposeFiles(); len(files) != 2 || files[0][0] != "docker-compose.yml" || files[1][0] != "docker-compose-galera.yml" {
		t.Fatal(files)
	}
}
