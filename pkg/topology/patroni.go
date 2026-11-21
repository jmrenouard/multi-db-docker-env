package topology

import (
	"context"

	"github.com/jmrenouard/multi-db-docker-env/pkg/docker"
)

// PatroniTopology manages the 3-node PostgreSQL 17 Patroni HA cluster with etcd and HAProxy.
type PatroniTopology struct{ *BaseTopology }

var patroniBuildImages = []struct{ tag, dockerfile, dir string }{
	{"patroni-rhel8-etcd:latest", "scripts/patroni/Dockerfile.etcd", "."},
	{"patroni-rhel8-postgresql:latest", "scripts/patroni/Dockerfile.postgresql", "."},
	{"patroni-rhel8-haproxy:latest", "scripts/patroni/Dockerfile.haproxy", "."},
}

// NewPatroniTopology returns the patroni topology definition.
func NewPatroniTopology() *PatroniTopology {
	return &PatroniTopology{
		BaseTopology: NewBaseTopology(
			"patroni",
			"PostgreSQL 17 Patroni High Availability cluster with etcd and HAProxy",
			[]string{"docker-compose-patroni.yml"},
			[]string{"patroni"},
		),
	}
}

// Up ensures all 3 Patroni images exist (auto-building any missing ones) before starting the stack.
func (p *PatroniTopology) Up(ctx context.Context, client *docker.Client) error {
	for _, img := range patroniBuildImages {
		if err := ensureImageFile(ctx, client, img.tag, img.dockerfile, img.dir); err != nil {
			return err
		}
	}
	return p.BaseTopology.Up(ctx, client)
}
