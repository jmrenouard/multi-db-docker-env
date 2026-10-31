package topology

import (
	"context"

	"github.com/jmrenouard/multi-db-docker-env/pkg/docker"
)

type GaleraTopology struct{ *BaseTopology }

func NewGaleraTopology() *GaleraTopology {
	return &GaleraTopology{
		BaseTopology: NewBaseTopology(
			"galera",
			"MariaDB 3-node Galera synchronous replication cluster with HAProxy",
			[]string{"docker-compose-galera.yml"},
			[]string{"mariadb"},
		),
	}
}

func (g *GaleraTopology) Up(ctx context.Context, client *docker.Client) error {
	if err := client.ComposeUp(ctx, g.ComposeFiles(), map[string]string{"MARIADB_GALERA_BOOTSTRAP": "1"}, true, "galera_01"); err != nil {
		return err
	}
	return client.ComposeUp(ctx, g.ComposeFiles(), nil, true)
}
