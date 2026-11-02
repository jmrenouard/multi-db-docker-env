package main

import (
	"context"
	"os"
	"testing"

	"github.com/jmrenouard/multi-db-docker-env/pkg/docker"
)

func TestDefaultAndResolveContainer(t *testing.T) {
	cases := map[string]string{
		"galera": "galera_01", "repli": "mariadb_02", "innodb": "mysql_node1",
		"patroni": "node1", "pgpool": "pgpool", "mongo": "mongo1", "mongo8": "mongo8_n1", "x": "mariadb-11.8",
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
}

func TestResolveVersion(t *testing.T) {
	orig := version
	defer func() { version = orig }()
	version = "2.0.20"

	origContent, hadOrig := os.ReadFile("VERSION")
	defer func() {
		if hadOrig == nil {
			_ = os.WriteFile("VERSION", origContent, 0644)
		} else {
			_ = os.Remove("VERSION")
		}
	}()

	// Fallback to static version when VERSION file is absent
	_ = os.Remove("VERSION")
	if got := resolveVersion(); got != "2.0.20" {
		t.Errorf("expected fallback 2.0.20, got %s", got)
	}

	// Reads and trims VERSION file from disk when present
	if err := os.WriteFile("VERSION", []byte("  2.0.20 \n"), 0644); err != nil {
		t.Fatalf("failed to write test VERSION file: %v", err)
	}

	if got := resolveVersion(); got != "2.0.20" {
		t.Errorf("expected 2.0.20 from VERSION file, got %s", got)
	}

	// Trim whitespace / custom release version
	if err := os.WriteFile("VERSION", []byte("\n  2.0.99-custom \r\n"), 0644); err != nil {
		t.Fatalf("failed to write custom test VERSION file: %v", err)
	}
	if got := resolveVersion(); got != "2.0.99-custom" {
		t.Errorf("expected 2.0.99-custom, got %s", got)
	}
}
