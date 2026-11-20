package topology

import (
	"context"

	"github.com/jmrenouard/multi-db-docker-env/pkg/docker"
)

// RepliTopology manages the 3-node MariaDB GTID primary-replica replication cluster.
type RepliTopology struct{ *BaseTopology }

// NewRepliTopology returns the repli topology definition.
func NewRepliTopology() *RepliTopology {
	return &RepliTopology{
		BaseTopology: NewBaseTopology(
			"repli",
			"MariaDB 3-node Primary-Replica GTID asynchronous replication cluster",
			[]string{"docker-compose-repli.yml"},
			[]string{"mariadb"},
		),
	}
}

// Up ensures the mariadb_ssh:004 image exists before running the BaseTopology lifecycle.
func (r *RepliTopology) Up(ctx context.Context, client *docker.Client) error {
	if err := ensureImage(ctx, client, "mariadb_ssh:004", "."); err != nil {
		return err
	}
	return r.BaseTopology.Up(ctx, client)
}
