package main

import (
	"context"
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
