package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/jmrenouard/multi-db-docker-env/pkg/catalog"
	"github.com/jmrenouard/multi-db-docker-env/pkg/config"
	"github.com/jmrenouard/multi-db-docker-env/pkg/docker"
)

func TestDefaultAndResolveContainer(t *testing.T) {
	cases := map[string]string{
		"galera": "galera_01", "repli": "mariadb_02", "innodb": "mysql_node1",
		"patroni": "node1", "pgpool": "pgpool", "mongo": "mongo1", "mongo8": "mongo8_n1",
		"pg17-baseline": "pg17_standalone", "pg-streaming": "pg_stream_primary", "pg-logical": "pg_logical_pub",
		"pg-birep": "pg_birep_node1", "pg18-streaming": "pg18_stream_primary",
		"pg18-logical": "pg18_logical_pub", "pg18-birep": "pg18_birep_node1",
		"pgedge": "pgedge_node1", "bucardo": "bucardo_node1",
		"citus": "citus_coord", "cockroach": "crdb_node1", "yugabyte": "yb_node1",
		"yt-cluster": "yt1", "mysql97": "mysql-9.7",
		"x":          "mariadb-11.4",
	}
	for topo, want := range cases {
		if got := defaultContainer(topo); got != want {
			t.Fatalf("%s: got %s, want %s", topo, got, want)
		}
	}
	cat := activeCatalog()
	c := docker.NewClientWithRunner(&docker.MockCommandRunner{Output: []byte("mdb-galera_01-1\n")})
	if got, _, ok := resolveEnvContainer(context.Background(), c, cat, "galera"); !ok || got != "mdb-galera_01-1" {
		t.Fatalf("resolve: %s ok=%v", got, ok)
	}
	pgC := docker.NewClientWithRunner(&docker.MockCommandRunner{Output: []byte("haproxy_pgpool\npgpool\n")})
	if got, _, ok := resolveEnvContainer(context.Background(), pgC, cat, "pgpool"); !ok || got != "pgpool" {
		t.Fatalf("exact env pgpool match failed: %s ok=%v", got, ok)
	}
	// Fallbacks: nil client, empty PS output, runner error
	if got, _, ok := resolveEnvContainer(context.Background(), nil, cat, "patroni"); !ok || got != "node1" {
		t.Fatalf("nil client fallback: %s ok=%v", got, ok)
	}
	emptyC := docker.NewClientWithRunner(&docker.MockCommandRunner{Output: []byte("")})
	if got, _, ok := resolveEnvContainer(context.Background(), emptyC, cat, "mongo"); !ok || got != "mongo1" {
		t.Fatalf("empty output fallback: %s ok=%v", got, ok)
	}
	errC := docker.NewClientWithRunner(&docker.MockCommandRunner{Err: errors.New("daemon down")})
	if got, _, ok := resolveEnvContainer(context.Background(), errC, cat, "citus"); !ok || got != "citus_coord" {
		t.Fatalf("error fallback: %s ok=%v", got, ok)
	}
}

func TestResolveVersion(t *testing.T) {
	orig := version
	defer func() { version = orig }()

	origContent, hadOrig := os.ReadFile("VERSION")
	defer func() {
		if hadOrig == nil {
			_ = os.WriteFile("VERSION", origContent, 0644)
		} else {
			_ = os.Remove("VERSION")
		}
	}()

	// Fallback to package-level version when VERSION file is absent
	_ = os.Remove("VERSION")
	if got := resolveVersion(); got != "2.6.2" {
		t.Errorf("expected fallback 2.6.2, got %s", got)
	}

	// Reads and trims VERSION file from disk when present
	if err := os.WriteFile("VERSION", []byte("  2.6.2 \n"), 0644); err != nil {
		t.Fatalf("failed to write test VERSION file: %v", err)
	}

	if got := resolveVersion(); got != "2.6.2" {
		t.Errorf("expected 2.6.2 from VERSION file, got %s", got)
	}

	// Trim whitespace / custom release version
	if err := os.WriteFile("VERSION", []byte("\n  2.0.99-custom \r\n"), 0644); err != nil {
		t.Fatalf("failed to write custom test VERSION file: %v", err)
	}
	if got := resolveVersion(); got != "2.0.99-custom" {
		t.Errorf("expected 2.0.99-custom, got %s", got)
	}

	// Fallback to ldflags-injected version when VERSION file is absent
	_ = os.Remove("VERSION")
	version = "2.0.99-injected"
	if got := resolveVersion(); got != "2.0.99-injected" {
		t.Errorf("expected injected version 2.0.99-injected, got %s", got)
	}
}

func TestLoadPassword(t *testing.T) {
	t.Setenv("DB_ROOT_PASSWORD", "")
	wd, _ := os.Getwd()
	tmp := t.TempDir()
	if err := os.Chdir(tmp); err != nil {
		t.Fatal(err)
	}
	defer func() { _ = os.Chdir(wd) }()

	if got := loadPassword(); got != config.DefaultConfig().RootPassword {
		t.Fatalf("expected default password, got %q", got)
	}
	if err := os.WriteFile(filepath.Join(tmp, ".env"), []byte("DB_ROOT_PASSWORD=custom_secret\n"), 0600); err != nil {
		t.Fatal(err)
	}
	if got := loadPassword(); got != "custom_secret" {
		t.Fatalf("expected custom_secret, got %q", got)
	}
}

func captureMain(t *testing.T, args ...string) string {
	t.Helper()
	origArgs, origOut := os.Args, os.Stdout
	r, w, err := os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	os.Args = append([]string{"mdb"}, args...)
	os.Stdout = w
	defer func() {
		os.Args = origArgs
		os.Stdout = origOut
	}()
	main()
	_ = w.Close()
	var buf bytes.Buffer
	_, _ = io.Copy(&buf, r)
	_ = r.Close()
	return buf.String()
}

func TestMain_InProcessSubcommands(t *testing.T) {
	for _, flag := range []string{"version", "--version", "-v"} {
		out := captureMain(t, flag)
		if !strings.Contains(out, "mdb version ") {
			t.Errorf("%s: unexpected output %q", flag, out)
		}
	}

	topoOut := captureMain(t, "topologies")
	for _, want := range []string{"galera", "patroni", "pg17-baseline", "pg-streaming", "pg18-streaming", "pg18-logical", "pg18-birep", "yt-cluster", "yugabyte"} {
		if !strings.Contains(topoOut, want) {
			t.Errorf("topologies output missing %q", want)
		}
	}

	tmp := t.TempDir()
	envFile := filepath.Join(tmp, "test.env")
	if err := os.WriteFile(envFile, []byte("DB_ROOT_PASSWORD=testpass\n"), 0600); err != nil {
		t.Fatal(err)
	}
	cfgOut := captureMain(t, "config", "--env", envFile)
	var parsed map[string]any
	if err := json.Unmarshal([]byte(cfgOut), &parsed); err != nil {
		t.Fatalf("config output invalid JSON: %v\n%s", err, cfgOut)
	}

	sslDir := filepath.Join(tmp, "ssl")
	genOut := captureMain(t, "pki", "generate", "galera", "--dir", sslDir)
	if !strings.Contains(genOut, "generated in") {
		t.Fatalf("unexpected pki generate output: %q", genOut)
	}
	verOut := captureMain(t, "pki", "verify", "galera", "--dir", sslDir)
	if !strings.Contains(verOut, "are valid") {
		t.Fatalf("unexpected pki verify output: %q", verOut)
	}
}

func TestHelperProcess(t *testing.T) {
	if os.Getenv("GO_WANT_HELPER_PROCESS") != "1" {
		return
	}
	for i, a := range os.Args {
		if a == "--" {
			os.Args = append([]string{"mdb"}, os.Args[i+1:]...)
			break
		}
	}
	main()
	os.Exit(0)
}

func TestMain_ExitErrors(t *testing.T) {
	cases := []struct {
		name string
		args []string
		want string
	}{
		{"no_args", nil, "Usage: mdb"},
		{"unknown_cmd", []string{"bogus"}, "Unknown command: bogus"},
		{"pki_no_action", []string{"pki"}, "Usage: mdb pki"},
		{"pki_bad_action", []string{"pki", "bogus"}, "Unknown PKI action"},
		{"up_no_topo", []string{"up"}, "Usage: mdb up"},
		{"down_unknown_topo", []string{"down", "doesnotexist"}, "Error:"},
		{"test_no_topo", []string{"test"}, "Usage: mdb test"},
		{"bench_unknown_topo", []string{"bench", "doesnotexist"}, "Error:"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			cmdArgs := append([]string{"-test.run=TestHelperProcess", "--"}, tc.args...)
			cmd := exec.Command(os.Args[0], cmdArgs...)
			cmd.Env = append(os.Environ(), "GO_WANT_HELPER_PROCESS=1")
			out, err := cmd.CombinedOutput()
			if err == nil {
				t.Fatalf("expected non-zero exit for %v, got 0 (out=%q)", tc.args, string(out))
			}
			if !strings.Contains(string(out), tc.want) {
				t.Errorf("expected output containing %q, got %q", tc.want, string(out))
			}
		})
	}
}

func TestHelpAndCatalogCommands(t *testing.T) {
	for _, h := range []string{"help", "--help", "-h"} {
		cmd := exec.Command(os.Args[0], "-test.run=TestHelperProcess", "--", h)
		cmd.Env = append(os.Environ(), "GO_WANT_HELPER_PROCESS=1")
		if out, err := cmd.CombinedOutput(); err != nil || !strings.Contains(string(out), "catalog") || !strings.Contains(string(out), "lint") || !strings.Contains(string(out), "setup") {
			t.Fatalf("%s failed err=%v out=%s", h, err, string(out))
		}
	}

	cat := activeCatalog()
	var buf bytes.Buffer
	if err := runCatalogCmd([]string{"--category", "standalone", "--engine", "pg", "--json"}, cat, &buf); err != nil {
		t.Fatalf("catalog json: %v", err)
	}
	var envs []catalog.Environment
	if err := json.Unmarshal(buf.Bytes(), &envs); err != nil || len(envs) != 4 {
		t.Fatalf("expected 4 pg envs, got %d err=%v", len(envs), err)
	}

	buf.Reset()
	if err := runCatalogCmd([]string{"--eol"}, cat, &buf); err != nil {
		t.Fatalf("catalog eol: %v", err)
	}
	for _, id := range []string{"mysql57", "mysql80", "mysql96", "mariadb106", "percona80"} {
		if !strings.Contains(buf.String(), id) {
			t.Fatalf("missing EOL %s", id)
		}
	}
}

func TestLifecycleUpAndDown(t *testing.T) {
	cat := activeCatalog()
	mock := &docker.MockCommandRunner{}
	client, ctx := docker.NewClientWithRunner(mock), context.Background()

	for id, date := range map[string]string{
		"mysql57": "2023-10-31", "mysql80": "2026-04-30", "mysql96": "2026-04-21",
		"mariadb106": "2026-07-06", "percona80": "2026-04-30",
	} {
		if err := runUpCmd(ctx, client, cat, id); err == nil || !strings.Contains(err.Error(), date) {
			t.Fatalf("%s: want EOL %s, got %v", id, date, err)
		}
	}

	if err := runUpCmd(ctx, client, cat, "mysql97"); err != nil {
		t.Fatalf("up mysql97: %v", err)
	}
	if got := strings.Join(mock.Calls[len(mock.Calls)-1], " "); !strings.Contains(got, "--profile traefik --profile mysql97") {
		t.Fatalf("unexpected up args: %s", got)
	}
	if err := runDownCmd(ctx, client, cat, "mysql97"); err != nil {
		t.Fatalf("down mysql97: %v", err)
	}
	if err := runDownCmd(ctx, client, cat, "all"); err != nil {
		t.Fatalf("down all: %v", err)
	}
	t.Setenv("DEFAULT_SERVICE", "postgres18")
	if got := resolveDefaultEnv(); got != "postgres18" {
		t.Fatalf("want postgres18, got %s", got)
	}
}

func TestStatusInfoAndLogs(t *testing.T) {
	cat := activeCatalog()
	mock := &docker.MockCommandRunner{
		Custom: func(_ context.Context, name string, args ...string) ([]byte, []byte, int, error) {
			line := strings.Join(args, " ")
			if strings.Contains(line, "ps --orphans=false --format") {
				return []byte("mysql-9.7\tmysql97\trunning\tUp 5s\t3306/tcp\n"), nil, 0, nil
			}
			if len(args) > 0 && args[0] == "logs" {
				return []byte("ready for connections\n"), nil, 0, nil
			}
			return nil, nil, 0, nil
		},
	}
	client, ctx := docker.NewClientWithRunner(mock), context.Background()

	wd, _ := os.Getwd()
	tmp := t.TempDir()
	_ = os.WriteFile(filepath.Join(tmp, "docker-compose.yml"), []byte("services:\n  traefik:\n    image: traefik:v3\n"), 0644)
	if err := os.Chdir(tmp); err != nil {
		t.Fatal(err)
	}
	defer func() { _ = os.Chdir(wd) }()

	var out bytes.Buffer
	if err := runStatusCmd(ctx, client, cat, []string{"--json"}, &out); err != nil || !strings.Contains(out.String(), `"service": "mysql97"`) {
		t.Fatalf("status json err=%v out=%s", err, out.String())
	}
	out.Reset()
	if err := runStatusCmd(ctx, client, cat, []string{"mysql97"}, &out); err != nil || !strings.Contains(out.String(), "mysql-9.7") {
		t.Fatalf("status standalone err=%v out=%s", err, out.String())
	}
	out.Reset()
	if err := runInfoCmd(ctx, client, &out); err != nil || !strings.Contains(out.String(), "Active service: mysql97") || !strings.Contains(out.String(), "ready for connections") {
		t.Fatalf("info err=%v out=%s", err, out.String())
	}
	if err := runStatusCmd(ctx, client, cat, []string{"unknown-env"}, &out); err == nil {
		t.Fatalf("expected error for unknown env")
	}
	for _, tc := range []struct {
		args []string
		want string
	}{
		{[]string{"mysql97"}, "compose -f docker-compose.yml --profile mysql97 logs --tail 100 mysql97"},
		{[]string{"standalone"}, "compose -f docker-compose.yml --profile * logs --tail 100"},
		{[]string{"galera", "--tail", "25", "-f"}, "compose -f docker-compose-galera.yml logs --tail 25 -f"},
		{nil, "logs --tail 100 mysql-9.7"},
	} {
		got, err := buildLogsArgs(ctx, client, cat, tc.args)
		if err != nil || strings.Join(got, " ") != tc.want {
			t.Fatalf("logs %v: got %q err=%v, want %q", tc.args, strings.Join(got, " "), err, tc.want)
		}
	}
}

func TestClientMyCnfAndDoctor(t *testing.T) {
	cat := activeCatalog()
	t.Setenv("DB_ROOT_PASSWORD", "")
	wd, _ := os.Getwd()
	tmp := t.TempDir()
	if err := os.Chdir(tmp); err != nil {
		t.Fatal(err)
	}
	defer func() { _ = os.Chdir(wd) }()

	// mycnf backup + warning without .env + TRAEFIK_MYSQL_PORT override
	var warn bytes.Buffer
	home := t.TempDir()
	t.Setenv("TRAEFIK_MYSQL_PORT", "13306")
	_ = os.WriteFile(filepath.Join(home, ".my.cnf"), []byte("old-cnf"), 0600)
	backed, err := writeMyCnf(home, loadPasswordWarn(&warn))
	if err != nil || !backed || !strings.Contains(warn.String(), "rootpass") {
		t.Fatalf("mycnf backed=%v err=%v warn=%q", backed, err, warn.String())
	}
	if bak, err := os.ReadFile(filepath.Join(home, ".my.cnf.bak")); err != nil || string(bak) != "old-cnf" {
		t.Fatalf("backup mismatch: %q err=%v", string(bak), err)
	}
	if cnf, err := os.ReadFile(filepath.Join(home, ".my.cnf")); err != nil || !strings.Contains(string(cnf), "password=rootpass") || !strings.Contains(string(cnf), "port=13306") {
		t.Fatalf("mycnf mismatch: %q err=%v", string(cnf), err)
	}

	// client engine command selection
	for _, tc := range []struct{ eng, id, ctr, want string }{
		{"postgres", "postgres17", "postgres-17", "psql -U postgres"},
		{"postgres", "pgpool", "pgpool", "psql -h 127.0.0.1 -p 9999 -U postgres"},
		{"postgres", "pgpool", "pg_node1", "psql -U postgres"},
		{"mongodb", "mongo8", "mongo8_n1", "mongosh --tls --tlsAllowInvalidCertificates --tlsCertificateKeyFile /etc/ssl/mongo/mongodb.pem"},
		{"mariadb", "galera", "galera_01", "command -v mariadb"},
		{"mysql", "mysql97", "mysql-9.7", "command -v mariadb"},
		{"cockroachdb", "cockroach", "crdb_node1", "/cockroach/cockroach sql"},
		{"yugabytedb", "yugabyte", "yb_node1", "ysqlsh"},
	} {
		env, cmd := buildClientCommand(tc.eng, tc.id, tc.ctr, "", "rootpass")
		if got := strings.Join(append(env, cmd...), " "); !strings.Contains(got, tc.want) {
			t.Fatalf("%s/%s: got %q, want %q", tc.eng, tc.id, got, tc.want)
		}
	}
	for _, c := range [][4]string{
		{"postgres", "pg-birep", "labdb", "psql -U postgres -d labdb"},
		{"postgres", "postgres17", "", "psql -U postgres"},
		{"cockroachdb", "crdb_node2", "", "--host=crdb_node2:26257"},
		{"yugabytedb", "yb_node2", "", "-h yb-node2"},
	} {
		_, m := buildClientCommand(c[0], c[1], c[1], c[2], "")
		if s := strings.Join(m, " "); !strings.Contains(s, c[3]) || (c[2] == "" && c[0] == "postgres" && s != c[3]) {
			t.Fatal(s)
		}
	}
	if eng, id := inferEngineAndID(cat, docker.ContainerStatus{Service: "pg_node1", Name: "pg_node1", File: "docker-compose-pgpool.yml"}); eng != "postgres" || id != "pgpool" {
		t.Fatalf("infer pgpool: got %s/%s", eng, id)
	}
	for _, c := range [][2]string{{"mysql_node1", "mysql"}, {"node1", "postgres"}} {
		if e, _ := inferEngineAndID(cat, docker.ContainerStatus{Service: c[0], Name: c[0]}); e != c[1] {
			t.Fatal(c[0], e)
		}
	}

	// doctor healthy & missing docker
	mock := &docker.MockCommandRunner{
		Custom: func(_ context.Context, _ string, args ...string) ([]byte, []byte, int, error) {
			if len(args) > 0 && args[0] == "compose" {
				return []byte("Docker Compose version v2.29.0"), nil, 0, nil
			}
			return []byte("27.0.0"), nil, 0, nil
		},
	}
	client, ctx := docker.NewClientWithRunner(mock), context.Background()
	var out bytes.Buffer
	okLook := func(b string) (string, error) { return "/bin/" + b, nil }
	noEnv := func(p string) (os.FileInfo, error) {
		if p == ".env" {
			return nil, os.ErrNotExist
		}
		return os.Stat(tmp)
	}
	origPortBound := doctorPortBound
	doctorPortBound = func(port string) bool { return port == "3306" }
	defer func() { doctorPortBound = origPortBound }()
	if err := runDoctorCmd(ctx, &out, "windows", okLook, noEnv, client); err != nil || !strings.Contains(out.String(), "mdb.cmd") || !strings.Contains(out.String(), "Docker Compose") || !strings.Contains(out.String(), "TRAEFIK_MYSQL_PORT") {
		t.Fatalf("doctor healthy err=%v out=%s", err, out.String())
	}
	out.Reset()
	if err := runDoctorCmd(ctx, &out, "linux", func(string) (string, error) { return "", errors.New("missing") }, noEnv, client); err == nil {
		t.Fatalf("expected error when docker missing")
	}
}

func TestAdminCommands(t *testing.T) {
	cat := catalog.NewCatalog(true)
	mock := &docker.MockCommandRunner{}
	client, ctx := docker.NewClientWithRunner(mock), context.Background()
	if err := runInjectCmd(ctx, client, cat, []string{"employees", "postgres17"}); err != nil {
		t.Fatalf("postgres inject should skip cleanly, got %v", err)
	}
	if err := runInjectCmd(ctx, client, cat, []string{"bad"}); err == nil {
		t.Fatalf("expected unsupported dataset error")
	}

	if s, a, err := planBackupRestore(false, []string{"galera", "--physical"}); err != nil || s != "./scripts/backup_physical.sh" || a[0] != "galera" {
		t.Fatalf("backup plan: s=%s a=%v err=%v", s, a, err)
	}
	if s, a, err := planBackupRestore(true, []string{"repli", "dump.sql.gz"}); err != nil || s != "./scripts/restore_logical.sh" || len(a) != 2 {
		t.Fatalf("restore plan: s=%s a=%v err=%v", s, a, err)
	}
	if _, _, err := planBackupRestore(true, []string{"galera"}); err == nil {
		t.Fatalf("expected error on missing restore file")
	}
	if tgts, err := auditTargets("all"); err != nil || len(tgts) != 3 {
		t.Fatalf("audit all: %v err=%v", tgts, err)
	}
	if _, err := auditTargets("bad"); err == nil {
		t.Fatalf("expected error on bad audit target")
	}

	wd, _ := os.Getwd()
	tmp := t.TempDir()
	_ = os.MkdirAll(filepath.Join(tmp, "reports"), 0755)
	rpt := filepath.Join(tmp, "reports", "r.html")
	_ = os.WriteFile(rpt, []byte("x"), 0644)
	_ = os.Chdir(tmp)
	defer func() { _ = os.Chdir(wd) }()
	if err := runCleanCmd(ctx, client, cat, []string{"reports"}); err != nil {
		t.Fatalf("clean reports: %v", err)
	}
	if _, err := os.Stat(rpt); !os.IsNotExist(err) {
		t.Fatalf("expected report removed")
	}
	if got := wslMountPath(`C:\Users\dev\repo`); got != "/mnt/c/Users/dev/repo" {
		t.Fatalf("wslMountPath: %q", got)
	}
	var mountCalls []string
	winMock := &docker.MockCommandRunner{Custom: func(_ context.Context, _ string, a ...string) ([]byte, []byte, int, error) {
		s := strings.Join(a, " ")
		mountCalls = append(mountCalls, s)
		if strings.Contains(s, `source=C:\repo`) {
			return nil, []byte("invalid mount"), 125, errors.New("win path")
		}
		return nil, nil, 0, nil
	}}
	if err := runAlpineCleanup(ctx, docker.NewClientWithRunner(winMock), `C:\repo`, []string{"datadir_01"}); err != nil || len(mountCalls) != 2 || !strings.Contains(mountCalls[1], "type=bind,source=/mnt/c/repo,target=/workspace") {
		t.Fatalf("alpine cleanup fallback: err=%v calls=%v", err, mountCalls)
	}

	oM, oP, oS := injectMaxAttempts, injectPollInterval, streamCommand
	defer func() { injectMaxAttempts, injectPollInterval, streamCommand = oM, oP, oS }()
	var ex error
	var s string
	mock.Custom = func(_ context.Context, _ string, a ...string) ([]byte, []byte, int, error) {
		if a[0] == "exec" && ex != nil {
			return nil, nil, 1, ex
		}
		return []byte("mariadb_01_x\nmariadb_01\n"), nil, 0, nil
	}
	streamCommand = func(_ context.Context, _ []string, _ io.Reader, _, _ io.Writer, n string, a ...string) error {
		s += n + " " + strings.Join(a, " ") + "\n"
		return nil
	}
	run := func(c context.Context) error { return runInjectCmd(c, client, cat, []string{"employees", "repli"}) }
	injectMaxAttempts, injectPollInterval, ex = 2, time.Millisecond, errors.New("down")
	if err := run(ctx); err == nil || !strings.Contains(err.Error(), "after 2 attempts") {
		t.Fatal(err)
	}
	cc, cancel := context.WithCancel(ctx)
	cancel()
	injectPollInterval = time.Second
	if err := run(cc); !errors.Is(err, context.Canceled) {
		t.Fatal(err)
	}
	ex = nil
	if err := run(ctx); err != nil || !strings.Contains(s, "mariadb_01:/var/tmp/") || !strings.Contains(s, " mariadb_01 ") {
		t.Fatal(err, s)
	}
}

func TestBenchRouting(t *testing.T) {
	cat := catalog.NewCatalog(true)
	for _, tc := range []struct{ id, wantStrat, wantArg, wantEnv string }{
		{"mariadb114", "sysbench", "", ""},
		{"galera", "sysbench", "", ""},
		{"mongo", "mongo-script", "", "MONGO_NODE1=mongo1"},
		{"mongo8", "mongo-script", "", "MONGO_NODE1=mongo8_n1"},
		{"postgres17", "pg-v2-script", "pg17-standalone", ""},
		{"pg-birep", "pg-v2-script", "pg-birep", ""},
		{"pg18-streaming", "pg18-script", "pg18-async-streaming", ""},
		{"yt-cluster", "yt-script", "", ""},
		{"postgres18", "pgbench", "", ""},
	} {
		env, ok := cat.Lookup(tc.id)
		if !ok {
			t.Fatalf("missing %s", tc.id)
		}
		p := planBenchmark(env)
		if p.Strategy != tc.wantStrat || p.Arg != tc.wantArg {
			t.Fatalf("%s: got %s/%s, want %s/%s", tc.id, p.Strategy, p.Arg, tc.wantStrat, tc.wantArg)
		}
		if tc.wantEnv != "" && (len(p.Env) == 0 || p.Env[0] != tc.wantEnv) {
			t.Fatalf("%s: got env %v, want %s", tc.id, p.Env, tc.wantEnv)
		}
	}

	client, ctx := docker.NewClientWithRunner(&docker.MockCommandRunner{}), context.Background()
	if err := runBenchCmd(ctx, client, cat, []string{"mysql80"}); err == nil || !strings.Contains(err.Error(), "2026-04-30") {
		t.Fatalf("expected EOL error for mysql80 bench, got %v", err)
	}
	if err := runBenchCmd(ctx, client, cat, nil); err == nil {
		t.Fatalf("expected usage error when env omitted")
	}
	if vt, ctr, err := resolveVerifierTarget(ctx, client, cat, "percona84"); err != nil || vt != "mysql" || ctr != "percona-server-8.4" {
		t.Fatalf("resolveVerifierTarget percona84: vt=%s ctr=%s err=%v", vt, ctr, err)
	}
	if _, err := runMySQLSysbench(ctx, client, "mysql-9.7", "oltp;rm -rf /", "rootpass", 2, time.Second); err == nil {
		t.Fatalf("expected invalid workload error")
	}
	sbOut := "transactions: 100 (50.00 per sec.)\nqueries: 2000 (1000.00 per sec.)\ntotal time: 2.0000s\ntotal number of events: 100\n"
	sbMock := &docker.MockCommandRunner{Custom: func(_ context.Context, _ string, a ...string) ([]byte, []byte, int, error) {
		j := strings.Join(a, " ")
		if strings.Contains(j, "command -v sysbench") {
			return nil, nil, 127, errors.New("missing")
		}
		if strings.Contains(j, "inspect -f") {
			return []byte("multi-db-docker-env_db-network \n"), nil, 0, nil
		}
		if strings.Contains(j, "run --rm") {
			return []byte(sbOut), nil, 0, nil
		}
		return []byte("ok\n"), nil, 0, nil
	}}
	if res, err := runMySQLSysbench(ctx, docker.NewClientWithRunner(sbMock), "mysql-9.7", "oltp_read_write", "rootpass", 2, 2*time.Second); err != nil || res.TPS != 50 {
		t.Fatalf("transient sysbench: res=%+v err=%v", res, err)
	}
}

func TestSetupLintAndTestSuite(t *testing.T) {
	cat, wd, tmp := activeCatalog(), "", t.TempDir()
	wd, _ = os.Getwd()
	for _, rel := range []string{"scripts/yt_cluster/setup_yt_cluster.sh", "tests/test_yt_cluster.sh", "conf/mongo-rs/setup_rs.sh", "tests/test_mongo_rs.sh", ".env.example", "docker-compose-pg17-baseline.yml"} {
		p := filepath.Join(tmp, rel)
		_ = os.MkdirAll(filepath.Dir(p), 0755)
		_ = os.WriteFile(p, []byte("ok\n"), 0644)
	}
	_ = os.Chdir(tmp)
	defer func() { _ = os.Chdir(wd) }()

	var out, errBuf bytes.Buffer
	var ran [][]string
	fx := func(_ context.Context, e []string, _ io.Reader, _, _ io.Writer, n string, a ...string) error {
		ran = append(ran, append([]string{strings.Join(e, ","), n}, a...))
		return nil
	}
	t.Setenv("DB_ROOT_PASSWORD", "")
	if err := runSetupCmd(context.Background(), cat, []string{"pg17-baseline"}, &out, &errBuf, fx); err != nil || !strings.Contains(out.String(), "No setup script") {
		t.Fatalf("pg17 setup: %v %s", err, out.String())
	}
	if err := runSetupCmd(context.Background(), cat, []string{"yt-cluster"}, &out, &errBuf, fx); err != nil || ran[0][2] != "scripts/yt_cluster/setup_yt_cluster.sh" || !strings.Contains(ran[0][0], "DB_ROOT_PASSWORD=rootpass") {
		t.Fatalf("yt setup: %v %v", err, ran)
	}
	ran = nil
	if err := runSetupCmd(context.Background(), cat, []string{"mongo8"}, &out, &errBuf, fx); err != nil || len(ran) != 1 || strings.Join(ran[0][2:], " ") != "conf/mongo-rs/setup_rs.sh mongo8_n1 mongo8_n2 mongo8_n3" || !strings.Contains(ran[0][0], "MONGO_NODES=mongo8_n1 mongo8_n2 mongo8_n3") {
		t.Fatalf("mongo8 setup: %v %v", err, ran)
	}
	if err := runSetupCmd(context.Background(), cat, []string{"mysql80"}, &out, &errBuf, fx); err == nil {
		t.Fatal("expected EOL")
	}

	mock := &docker.MockCommandRunner{Custom: func(_ context.Context, _ string, a ...string) ([]byte, []byte, int, error) {
		if strings.Contains(strings.Join(a, " "), "rs.status()") {
			return []byte(`{"members":[{"health":1,"state":1,"stateStr":"PRIMARY"},{"health":1,"state":2},{"health":1,"state":2}]}`), nil, 0, nil
		}
		return []byte("1\n"), nil, 0, nil
	}}
	client := docker.NewClientWithRunner(mock)
	out.Reset()
	if err := runLintCmd(context.Background(), client, &out, &errBuf); err != nil || !strings.Contains(out.String(), "bash -n passed") || !strings.Contains(out.String(), "docker-compose-pg17-baseline.yml") {
		t.Fatalf("lint: %v %s", err, out.String())
	}
	if got := strings.Join(mock.Calls[len(mock.Calls)-1], " "); !strings.Contains(got, "--env-file .env.example -f docker-compose-pg17-baseline.yml config -q") {
		t.Fatalf("lint args: %s", got)
	}

	out.Reset()
	ran = nil
	if err := runTestCmd(context.Background(), client, cat, []string{"yt-cluster", "--suite"}, &out, &errBuf, fx); err != nil || !strings.Contains(out.String(), `"HEALTHY"`) || ran[0][2] != "tests/test_yt_cluster.sh" || !strings.Contains(ran[0][0], "DB_ROOT_PASSWORD=rootpass") {
		t.Fatalf("test --suite: %v %s %v", err, out.String(), ran)
	}
	ran = nil
	if err := runTestCmd(context.Background(), client, cat, []string{"mongo8", "--suite"}, &out, &errBuf, fx); err != nil || len(ran) != 1 || strings.Join(ran[0][2:], " ") != "tests/test_mongo_rs.sh mongo8_n1 mongo8_n2 mongo8_n3" || !strings.Contains(ran[0][0], "MONGO_NODES=mongo8_n1 mongo8_n2 mongo8_n3") {
		t.Fatalf("mongo8 test --suite: %v %v", err, ran)
	}
	if err := runTestCmd(context.Background(), client, cat, []string{"pg17-baseline", "--suite"}, &out, &errBuf, fx); err == nil {
		t.Fatal("expected missing suite")
	}
}
