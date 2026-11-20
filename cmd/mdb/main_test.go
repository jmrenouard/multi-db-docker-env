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

	"github.com/jmrenouard/multi-db-docker-env/pkg/catalog"
	"github.com/jmrenouard/multi-db-docker-env/pkg/config"
	"github.com/jmrenouard/multi-db-docker-env/pkg/docker"
)

func TestDefaultAndResolveContainer(t *testing.T) {
	cases := map[string]string{
		"galera": "galera_01", "repli": "mariadb_02", "innodb": "mysql_node1",
		"patroni": "node1", "pgpool": "pgpool", "mongo": "mongo1", "mongo8": "mongo8_n1",
		"pg-streaming": "pg_stream_primary", "pg-logical": "pg_logical_pub",
		"pg-birep": "pg_birep_node1", "pg18-streaming": "pg18_stream_primary",
		"pg18-logical": "pg18_logical_pub", "pg18-birep": "pg18_birep_node1",
		"pgedge": "pgedge_node1", "bucardo": "bucardo_node1",
		"citus": "citus_coord", "cockroach": "crdb_node1", "yugabyte": "yb_node1",
		"yt-cluster": "yt1",
		"x":          "mariadb-11.8",
	}
	for topo, want := range cases {
		if got := defaultContainer(topo); got != want {
			t.Fatalf("%s: got %s, want %s", topo, got, want)
		}
	}
	c := docker.NewClientWithRunner(&docker.MockCommandRunner{Output: []byte("mdb-galera_01-1\n")})
	if got := resolveContainer(context.Background(), c, "galera"); got != "mdb-galera_01-1" {
		t.Fatalf("resolve: %s", got)
	}
	// Fallbacks: nil client, empty PS output, runner error
	if got := resolveContainer(context.Background(), nil, "patroni"); got != "node1" {
		t.Fatalf("nil client fallback: %s", got)
	}
	emptyC := docker.NewClientWithRunner(&docker.MockCommandRunner{Output: []byte("")})
	if got := resolveContainer(context.Background(), emptyC, "mongo"); got != "mongo1" {
		t.Fatalf("empty output fallback: %s", got)
	}
	errC := docker.NewClientWithRunner(&docker.MockCommandRunner{Err: errors.New("daemon down")})
	if got := resolveContainer(context.Background(), errC, "citus"); got != "citus_coord" {
		t.Fatalf("error fallback: %s", got)
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
	if got := resolveVersion(); got != "2.4.0" {
		t.Errorf("expected fallback 2.4.0, got %s", got)
	}

	// Reads and trims VERSION file from disk when present
	if err := os.WriteFile("VERSION", []byte("  2.4.0 \n"), 0644); err != nil {
		t.Fatalf("failed to write test VERSION file: %v", err)
	}

	if got := resolveVersion(); got != "2.4.0" {
		t.Errorf("expected 2.4.0 from VERSION file, got %s", got)
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
	for _, want := range []string{"galera", "patroni", "pg-streaming", "pg18-streaming", "pg18-logical", "pg18-birep", "yt-cluster", "yugabyte"} {
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
		if out, err := cmd.CombinedOutput(); err != nil || !strings.Contains(string(out), "catalog") {
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
			if strings.Contains(line, "ps --format") {
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
