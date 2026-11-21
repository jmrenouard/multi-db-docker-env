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

	if err := c.ComposeUp(ctx, []string{"f1.yml"}, map[string]string{"K": "V"}, true, "s1"); err != nil || !strings.Contains(strings.Join(m.Calls[0], " "), "compose -f f1.yml up -d s1") || strings.Contains(strings.Join(m.Calls[0], " "), "--env") || len(m.EnvCalls) != 1 || m.EnvCalls[0][0] != "K=V" {
		t.Fatal(err)
	}
	if err := c.ComposeDown(ctx, []string{"f1.yml"}, true); err != nil || !strings.Contains(strings.Join(m.Calls[1], " "), "compose -f f1.yml down -v") {
		t.Fatalf("compose down: %v", err)
	}
	_ = c.ComposeDown(ctx, []string{"f1.yml"}, false)
	if strings.Contains(strings.Join(m.Calls[2], " "), "-v") {
		t.Fatal("unexpected -v")
	}
	if names, err := c.ComposePS(ctx, []string{"f.yml"}); err != nil || len(names) != 2 || names[0] != "s1" || !strings.Contains(strings.Join(m.Calls[3], " "), "ps --orphans=false --format") {
		t.Fatalf("compose ps: %v, %v, call=%v", names, err, m.Calls[3])
	}
	if _, err := c.ComposePS(ctx, []string{"docker-compose.yml"}); err != nil || !strings.Contains(strings.Join(m.Calls[4], " "), "--profile * ps --orphans=false") {
		t.Fatalf("compose ps standalone: %v, call=%v", err, m.Calls[4])
	}
	m.Output = []byte("out")
	if logs, err := c.ComposeLogs(ctx, []string{"f.yml"}, 50, "s1"); err != nil || logs != "out" || !strings.Contains(strings.Join(m.Calls[5], " "), "compose -f f.yml logs --tail 50 s1") {
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
	if w := mergeEnv([]string{"PATH=x"}, []string{"MARIADB_GALERA_BOOTSTRAP=1"}, "wsl.exe", "windows"); !strings.Contains(strings.Join(w, ";"), "WSLENV=MARIADB_GALERA_BOOTSTRAP") {
		t.Fatal(w)
	}
	winEnv := mergeEnv([]string{"PATH=x", "WSLENV=EXISTING/u"}, []string{"MONGO_NODES=a b", "DB_ROOT_PASSWORD=rootpass"}, `C:\Windows\system32\bash.exe`, "windows")
	if got := strings.Join(winEnv, ";"); !strings.Contains(got, "WSLENV=EXISTING/u:MONGO_NODES:DB_ROOT_PASSWORD") {
		t.Fatalf("mergeEnv windows bash: %v", winEnv)
	}
	if dEnv := mergeEnv([]string{"PATH=x"}, []string{"MARIADB_GALERA_BOOTSTRAP=1"}, "docker.cmd", "windows"); !strings.Contains(strings.Join(dEnv, ";"), "WSLENV=MARIADB_GALERA_BOOTSTRAP") {
		t.Fatalf("mergeEnv windows docker: %v", dEnv)
	}
	if linEnv := mergeEnv([]string{"PATH=x"}, []string{"K=V"}, "bash", "linux"); strings.Contains(strings.Join(linEnv, ";"), "WSLENV=") {
		t.Fatalf("mergeEnv linux unexpected WSLENV: %v", linEnv)
	}
}

func TestClient_ProfilesDownAllPSStatusAndImages(t *testing.T) {
	ctx := context.Background()
	m := &MockCommandRunner{Output: []byte("mariadb-11.4\tmariadb114\trunning\tUp 5s\t3306/tcp\n")}
	c := NewClientWithRunner(m)

	if err := c.ComposeUpProfiles(ctx, []string{"docker-compose.yml"}, []string{"traefik", "mariadb114"}, map[string]string{"A": "1"}, true); err != nil || !strings.Contains(strings.Join(m.Calls[0], " "), "--profile traefik --profile mariadb114 up -d") || strings.Contains(strings.Join(m.Calls[0], " "), "--env") || len(m.EnvCalls) != 1 || m.EnvCalls[0][0] != "A=1" {
		t.Fatal(err)
	}
	if err := c.ComposeDownProfiles(ctx, []string{"docker-compose.yml"}, []string{"*"}, true); err != nil || !strings.Contains(strings.Join(m.Calls[1], " "), "--profile * down -v") {
		t.Fatal(err)
	}
	if st, err := c.ComposePSStatusAll(ctx, [][]string{{"docker-compose.yml"}, {"docker-compose-galera.yml"}}); err != nil || len(st) != 1 || st[0].Service != "mariadb114" || !strings.Contains(strings.Join(m.Calls[2], " "), "ps --orphans=false --format") {
		t.Fatal(st, err, m.Calls[2])
	}
	m.Calls, m.EnvCalls = nil, nil
	if err := c.ComposeDownAll(ctx, [][]string{{"docker-compose.yml"}}, "CustomProj"); err != nil || len(m.Calls) < 3 || !strings.Contains(strings.Join(m.Calls[1], " "), "project=CustomProj") {
		t.Fatal(err, m.Calls)
	}
	if ok, err := c.ImageExists(ctx, "mariadb_ssh:004"); err != nil || !ok {
		t.Fatal(ok, err)
	}
	m.ExitCode, m.Err, m.Stderr = 1, errors.New("x"), []byte("Error response from daemon: No such image: missing:1")
	if ok, err := c.ImageExists(ctx, "missing:1"); err != nil || ok {
		t.Fatal(ok, err)
	}
	m.Stderr = []byte("Cannot connect to the Docker daemon")
	if _, err := c.ImageExists(ctx, "missing:1"); err == nil {
		t.Fatal("want err")
	}
	if _, err := c.ComposePSStatusAll(ctx, [][]string{{"docker-compose.yml"}}); err == nil {
		t.Fatal("want err")
	}
	if err := c.ComposeDownAll(ctx, [][]string{{"docker-compose.yml"}}, "proj"); err == nil {
		t.Fatal("want err")
	}
	rmFail := NewClientWithRunner(&MockCommandRunner{Custom: func(_ context.Context, _ string, a ...string) ([]byte, []byte, int, error) {
		if a[0] == "ps" {
			return []byte("cid1\n"), nil, 0, nil
		}
		if a[0] == "rm" {
			return nil, []byte("denied"), 1, errors.New("rm")
		}
		return nil, nil, 0, nil
	}})
	if err := rmFail.ComposeDownAll(ctx, [][]string{{"docker-compose.yml"}}, "proj"); err == nil || !strings.Contains(err.Error(), "docker rm failed") {
		t.Fatal(err)
	}
	if err := c.BuildImage(ctx, "mariadb_ssh:004", "."); err == nil {
		t.Fatal("want err")
	}
	m.ExitCode, m.Err, m.Stderr = 0, nil, nil
	if err := c.BuildImage(ctx, "mariadb_ssh:004", ""); err != nil {
		t.Fatal(err)
	}
	if err := c.BuildImageFile(ctx, "patroni-rhel8-etcd:latest", "scripts/patroni/Dockerfile.etcd", "."); err != nil || !strings.Contains(strings.Join(m.Calls[len(m.Calls)-1], " "), "build -t patroni-rhel8-etcd:latest -f scripts/patroni/Dockerfile.etcd .") {
		t.Fatalf("BuildImageFile: %v %v", err, m.Calls[len(m.Calls)-1])
	}
	if err := c.PullImage(ctx, "postgres:17"); err != nil || !strings.Contains(strings.Join(m.Calls[len(m.Calls)-1], " "), "docker pull postgres:17") {
		t.Fatalf("PullImage: %v %v", err, m.Calls[len(m.Calls)-1])
	}
	m.Output = []byte("postgres:17\n<none>:<none>\nmariadb_ssh:004\n")
	if imgs, err := c.ListLocalImages(ctx); err != nil || !imgs["postgres:17"] || !imgs["mariadb_ssh:004"] || len(imgs) != 2 {
		t.Fatalf("ListLocalImages: %v %v", imgs, err)
	}
	m.ExitCode, m.Err, m.Stderr = 1, errors.New("pull err"), []byte("denied")
	if err := c.PullImage(ctx, "postgres:17"); err == nil {
		t.Fatal("want PullImage err")
	}
	if _, err := c.ListLocalImages(ctx); err == nil {
		t.Fatal("want ListLocalImages err")
	}
	m.ExitCode, m.Err, m.Stderr = 0, nil, nil
	if _, _, _, err := c.RunWithEnv(ctx, []string{"K=V"}, "bash", "s.sh"); err != nil || len(m.EnvCalls) != 1 {
		t.Fatal(err, m.EnvCalls)
	}
	t.Setenv("COMPOSE_PROJECT_NAME", "override-proj")
	if ProjectName() != "override-proj" {
		t.Fatal(ProjectName())
	}
	t.Setenv("COMPOSE_PROJECT_NAME", "")
	wd, _ := os.Getwd()
	defer func() { _ = os.Chdir(wd) }()
	tmp := t.TempDir()
	_ = os.Chdir(tmp)
	if ProjectName() != filepath.Base(tmp) {
		t.Fatal(ProjectName())
	}
	_ = os.WriteFile("docker-compose.yml", []byte("services: {}\n"), 0644)
	_ = os.WriteFile("docker-compose-galera.yml", []byte("services: {}\n"), 0644)
	if files := DiscoverComposeFiles(); len(files) != 2 || files[0][0] != "docker-compose.yml" {
		t.Fatal(files)
	}
}

func TestClient_ResolveContainer(t *testing.T) {
	ctx := context.Background()
	if (*Client)(nil).ResolveContainer(ctx, "x") != "x" {
		t.Fatal("nil")
	}
	for _, tc := range []struct{ o, b, w string }{
		{"", "", ""},
		{"haproxy_pgpool\npgpool\n", "pgpool", "pgpool"},
		{"mdb-galera_01-1\n", "galera_01", "mdb-galera_01-1"},
		{"", "mongo1", "mongo1"},
	} {
		if NewClientWithRunner(&MockCommandRunner{Output: []byte(tc.o)}).ResolveContainer(ctx, tc.b) != tc.w {
			t.Fatal(tc)
		}
	}
	if NewClientWithRunner(&MockCommandRunner{Err: errors.New("x")}).ResolveContainer(ctx, "c") != "c" {
		t.Fatal("err")
	}
}
