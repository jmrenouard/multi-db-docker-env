package topology

import (
	"context"
	"errors"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/jmrenouard/multi-db-docker-env/pkg/docker"
)

func withTempDir(t *testing.T) {
	t.Helper()
	wd, _ := os.Getwd()
	_ = os.Chdir(t.TempDir())
	t.Cleanup(func() { _ = os.Chdir(wd) })
}

func TestRegistry_Default(t *testing.T) {
	r := DefaultRegistry()
	expected := []string{"bucardo", "citus", "cockroach", "galera", "innodb", "mongo", "mongo8", "patroni", "pg-birep", "pg-logical", "pg-streaming", "pg18-birep", "pg18-logical", "pg18-streaming", "pgedge", "pgpool", "repli", "standalone", "yt-cluster", "yugabyte"}
	list := r.List()
	if len(list) != len(expected) {
		t.Fatalf("expected %d, got %d", len(expected), len(list))
	}
	for i, name := range expected {
		if list[i].Name() != name {
			t.Errorf("expected %s, got %s", name, list[i].Name())
		}
		topo, err := r.Get(name)
		if err != nil || len(topo.ComposeFiles()) == 0 || topo.Description() == "" {
			t.Fatalf("invalid %s", name)
		}
	}
	if crdb, _ := r.Get("cockroach"); !strings.Contains(crdb.Description(), "v25.4") {
		t.Fatalf("stale cockroach: %s", crdb.Description())
	}
	if _, err := r.Get("none"); err == nil {
		t.Fatal("expected err")
	}
	withTempDir(t)
	if r2 := DefaultRegistry(); len(r2.List()) != 19 {
		t.Fatalf("expected 19 without yt-cluster, got %d", len(r2.List()))
	}
}

func TestBaseTopology_Lifecycle(t *testing.T) {
	withTempDir(t)
	origPoll := defaultPollInterval
	defaultPollInterval = time.Millisecond
	defer func() { defaultPollInterval = origPoll }()

	ctx := context.Background()
	mock := &docker.MockCommandRunner{Output: []byte("g1\n1\n")}
	client := docker.NewClientWithRunner(mock)
	topo := NewGaleraTopology()

	if err := topo.Up(ctx, client); err != nil || len(mock.Calls) != 2 || !strings.Contains(strings.Join(mock.Calls[0], " "), "MARIADB_GALERA_BOOTSTRAP=1 up -d galera_01") || !strings.Contains(strings.Join(mock.Calls[1], " "), "compose -f docker-compose-galera.yml up -d") {
		t.Fatalf("Up: %v, calls: %v", err, mock.Calls)
	}
	if err := topo.Down(ctx, client); err != nil || !strings.Contains(strings.Join(mock.Calls[2], " "), "compose -f docker-compose-galera.yml down -v") {
		t.Fatalf("Down: %v", err)
	}
	repli := NewRepliTopology()
	if err := repli.Up(ctx, client); err != nil || !strings.Contains(strings.Join(mock.Calls[len(mock.Calls)-1], " "), "bash scripts/setup_repli.sh") {
		t.Fatalf("Repli Up setup script: %v, calls: %v", err, mock.Calls)
	}
	if !filesExist("ssl/ca-cert.pem", "ssl/server-cert.pem") {
		t.Fatal("missing mariadb certs")
	}
	mock.Output = []byte("g1\n")
	st, err := topo.Status(ctx, client)
	if err != nil || !st.Running || len(st.Services) != 1 || topo.Verify(ctx, client) != nil {
		t.Fatalf("status running: %v", err)
	}
	mock.Output = []byte("")
	st, err = topo.Status(ctx, client)
	if err != nil || st.Running || topo.Verify(ctx, client) == nil {
		t.Fatalf("status stopped: %v", err)
	}
	mock.Err, mock.ExitCode = errors.New("err"), 1
	if _, err := topo.Status(ctx, client); err == nil {
		t.Fatal("expected err")
	}
}

func TestBaseTopology_AutoCertsMongo8PgPoolAndTimeout(t *testing.T) {
	withTempDir(t)
	origPoll, origTO := defaultPollInterval, defaultReadyTimeout
	defaultPollInterval, defaultReadyTimeout = time.Millisecond, 10*time.Millisecond
	defer func() { defaultPollInterval, defaultReadyTimeout = origPoll, origTO }()

	ctx := context.Background()
	mock := &docker.MockCommandRunner{Custom: func(_ context.Context, n string, a ...string) ([]byte, []byte, int, error) {
		j := strings.Join(append([]string{n}, a...), " ")
		if strings.Contains(j, "status=running") {
			return []byte("haproxy_mongo8\npgpool\n"), nil, 0, nil
		}
		if strings.Contains(j, "SHOW pool_nodes") {
			return []byte("0 | pg_node1 | 5432 | up\n"), nil, 0, nil
		}
		return []byte("ok\n"), nil, 0, nil
	}}
	client := docker.NewClientWithRunner(mock)

	if err := NewMongo8Topology().Up(ctx, client); err != nil {
		t.Fatal(err)
	}
	if !filesExist("ssl/certs/mongo8/ca.pem", "ssl/certs/mongo8/mongodb.pem") {
		t.Fatal("missing mongo8 certs")
	}
	if len(mock.EnvCalls) == 0 || mock.EnvCalls[0][0] != "MONGO_NODES=mongo8_n1 mongo8_n2 mongo8_n3" {
		t.Fatal(mock.EnvCalls)
	}
	if !strings.Contains(strings.Join(mock.Calls[len(mock.Calls)-2], " "), "setup_rs.sh mongo8_n1 mongo8_n2 mongo8_n3") {
		t.Fatal(mock.Calls)
	}
	if err := NewPgPoolTopology().Up(ctx, client); err != nil || !filesExist("ssl/pgpool/ca-cert.pem", "ssl/pgpool/server.crt") {
		t.Fatal(err)
	}
	if err := NewPatroniTopology().EnsureCerts(ctx, client); err != nil || !strings.Contains(strings.Join(mock.Calls[len(mock.Calls)-1], " "), "scripts/patroni/generate_certs.sh") {
		t.Fatal(err)
	}
	fail := docker.NewClientWithRunner(&docker.MockCommandRunner{Err: errors.New("wait"), ExitCode: 1})
	if err := NewInnoDBTopology().waitBeforeSetup(ctx, fail); err == nil || !strings.Contains(err.Error(), "timeout waiting for") {
		t.Fatal(err)
	}
}

func TestMongoTopologies_RequiredCerts(t *testing.T) {
	for name, want := range map[string][]string{
		"mongo":  {"ssl/mongo/ca.pem", "ssl/mongo/mongodb.pem"},
		"mongo8": {"ssl/certs/mongo8/ca.pem", "ssl/certs/mongo8/mongodb.pem"},
	} {
		topo, _ := DefaultRegistry().Get(name)
		if got := topo.RequiredCerts(); got[0] != want[0] || got[1] != want[1] {
			t.Fatalf("%s: %v != %v", name, got, want)
		}
	}
}
