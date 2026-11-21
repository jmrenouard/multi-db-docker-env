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
	expected := []string{"bucardo", "citus", "cockroach", "galera", "innodb", "mongo", "mongo8", "patroni", "pg-birep", "pg-logical", "pg-streaming", "pg17-baseline", "pg18-birep", "pg18-logical", "pg18-streaming", "pgedge", "pgpool", "repli", "standalone", "yt-cluster", "yugabyte"}
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
	if r2 := DefaultRegistry(); len(r2.List()) != 21 {
		t.Fatalf("expected 21 unconditionally, got %d", len(r2.List()))
	}
}

func TestStandaloneTopology_UpProfileAndDown(t *testing.T) {
	ctx := context.Background()
	mock := &docker.MockCommandRunner{}
	client := docker.NewClientWithRunner(mock)
	s := NewStandaloneTopology()

	if err := s.Up(ctx, client); err != nil {
		t.Fatalf("Up: %v", err)
	}
	if got := strings.Join(mock.Calls[0], " "); !strings.Contains(got, "--profile traefik --profile mariadb114") {
		t.Fatalf("expected default mariadb114 profile, got %s", got)
	}
	if err := s.UpProfile(ctx, client, "postgres18"); err != nil {
		t.Fatalf("UpProfile postgres18: %v", err)
	}
	if got := strings.Join(mock.Calls[1], " "); !strings.Contains(got, "--profile traefik --profile postgres18") {
		t.Fatalf("expected postgres18 profile, got %s", got)
	}
	if err := s.UpProfile(ctx, client, "standalone"); err != nil {
		t.Fatalf("UpProfile standalone: %v", err)
	}
	if got := strings.Join(mock.Calls[2], " "); !strings.Contains(got, "--profile traefik --profile mariadb114") {
		t.Fatalf("expected fallback mariadb114 profile, got %s", got)
	}
	if err := s.Down(ctx, client); err != nil {
		t.Fatalf("Down: %v", err)
	}
	if got := strings.Join(mock.Calls[3], " "); !strings.Contains(got, "--profile * down -v") {
		t.Fatalf("expected --profile * down, got %s", got)
	}
}

func TestGaleraAndRepli_BuildAndReadiness(t *testing.T) {
	withTempDir(t)
	origPoll := defaultPollInterval
	defaultPollInterval = time.Millisecond
	defer func() { defaultPollInterval = origPoll }()

	ctx := context.Background()
	var imagePresent bool
	mock := &docker.MockCommandRunner{
		Custom: func(_ context.Context, name string, args ...string) ([]byte, []byte, int, error) {
			joined := strings.Join(append([]string{name}, args...), " ")
			if strings.Contains(joined, "image inspect mariadb_ssh:004") {
				if imagePresent {
					return []byte("[]"), nil, 0, nil
				}
				return nil, []byte("Error response from daemon: No such image: mariadb_ssh:004"), 1, errors.New("missing")
			}
			if strings.Contains(joined, "wsrep_local_state_comment") {
				return []byte("wsrep_local_state_comment\tSynced\n"), nil, 0, nil
			}
			if strings.Contains(joined, "SELECT 1") {
				return []byte("1\n"), nil, 0, nil
			}
			return []byte("g1\n"), nil, 0, nil
		},
	}
	client := docker.NewClientWithRunner(mock)
	galera := NewGaleraTopology()
	if err := galera.Up(ctx, client); err != nil {
		t.Fatalf("Galera Up: %v", err)
	}
	if !filesExist("ssl/ca-cert.pem", "ssl/server-cert.pem", "ssl/client-cert.pem") {
		t.Fatal("expected galera certs auto-generated")
	}
	joinCalls := func() string {
		var lines []string
		for _, c := range mock.Calls {
			lines = append(lines, strings.Join(c, " "))
		}
		return strings.Join(lines, "\n")
	}
	joined := joinCalls()
	for _, want := range []string{"docker build -t mariadb_ssh:004 .", "MARIADB_GALERA_BOOTSTRAP=1", "up -d galera_01", "up -d galera_02", "up -d galera_03", "up -d haproxy_galera"} {
		if !strings.Contains(joined, want) {
			t.Fatalf("missing %q in calls:\n%s", want, joined)
		}
	}

	imagePresent = true
	t.Setenv("DB_ROOT_PASSWORD", "ci-secret")
	if err := galera.Up(ctx, client); err != nil {
		t.Fatalf("Galera Up with DB_ROOT_PASSWORD set: %v", err)
	}
	mock.Calls = nil
	repli := NewRepliTopology()
	if err := repli.Up(ctx, client); err != nil {
		t.Fatalf("Repli Up: %v", err)
	}
	if repliCalls := joinCalls(); strings.Contains(repliCalls, "docker build") || !strings.Contains(repliCalls, "docker exec -e MYSQL_PWD=ci-secret g1 mariadb") {
		t.Fatalf("unexpected repli calls:\n%s", repliCalls)
	}
	if last := strings.Join(mock.Calls[len(mock.Calls)-1], " "); !strings.Contains(last, "bash scripts/setup_repli.sh") {
		t.Fatalf("expected setup_repli.sh last, got %s", last)
	}
	if err := galera.Down(ctx, client); err != nil {
		t.Fatalf("Down: %v", err)
	}

	plainMock := &docker.MockCommandRunner{Output: []byte("g1\n")}
	plainClient := docker.NewClientWithRunner(plainMock)
	st, err := galera.Status(ctx, plainClient)
	if err != nil || !st.Running || len(st.Services) != 1 || galera.Verify(ctx, plainClient) != nil {
		t.Fatalf("status running: %+v %v", st, err)
	}
	plainMock.Output = []byte("")
	st, err = galera.Status(ctx, plainClient)
	if err != nil || st.Running || galera.Verify(ctx, plainClient) == nil {
		t.Fatalf("status stopped: %+v %v", st, err)
	}
	plainMock.Err, plainMock.ExitCode = errors.New("err"), 1
	if _, err := galera.Status(ctx, plainClient); err == nil {
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

	t.Setenv("DB_ROOT_PASSWORD", "")
	if err := NewMongo8Topology().Up(ctx, client); err != nil {
		t.Fatal(err)
	}
	if !filesExist("ssl/certs/mongo8/ca.pem", "ssl/certs/mongo8/mongodb.pem") {
		t.Fatal("missing mongo8 certs")
	}
	if len(mock.EnvCalls) == 0 || !strings.Contains(strings.Join(mock.EnvCalls[0], ","), "MONGO_NODES=mongo8_n1 mongo8_n2 mongo8_n3") || !strings.Contains(strings.Join(mock.EnvCalls[0], ","), "DB_ROOT_PASSWORD=rootpass") {
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
