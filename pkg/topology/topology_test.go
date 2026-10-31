package topology

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/jmrenouard/multi-db-docker-env/pkg/docker"
)

func TestRegistry_Default(t *testing.T) {
	r := DefaultRegistry()
	expected := []string{"galera", "innodb", "mongo", "mongo8", "patroni", "pgpool", "repli", "standalone"}
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
	if _, err := r.Get("none"); err == nil {
		t.Fatal("expected err")
	}
}

func TestBaseTopology_Lifecycle(t *testing.T) {
	ctx := context.Background()
	mock := &docker.MockCommandRunner{Output: []byte("g1\n")}
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
