package topology

import (
	"context"
	"strings"

	"github.com/jmrenouard/multi-db-docker-env/pkg/docker"
)

// GaleraTopology manages the 3-node MariaDB Galera synchronous replication cluster with HAProxy.
type GaleraTopology struct{ *BaseTopology }

// NewGaleraTopology returns the galera topology definition.
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

func ensureImage(ctx context.Context, client *docker.Client, tag, dir string) error {
	exists, err := client.ImageExists(ctx, tag)
	if err != nil || exists {
		return err
	}
	return client.BuildImage(ctx, tag, dir)
}

// Up ensures certs and image exist, bootstraps galera_01, joins nodes 2-3 sequentially with readiness polling, and starts HAProxy.
func (g *GaleraTopology) Up(ctx context.Context, client *docker.Client) error {
	if err := g.EnsureCerts(ctx, client); err != nil {
		return err
	}
	if err := ensureImage(ctx, client, "mariadb_ssh:004", "."); err != nil {
		return err
	}
	pass := rootPassword()
	bootEnv := defaultComposeEnv()
	bootEnv["MARIADB_GALERA_BOOTSTRAP"] = "1"
	if err := client.ComposeUp(ctx, g.ComposeFiles(), bootEnv, true, "galera_01"); err != nil {
		return err
	}
	if err := waitGaleraSynced(ctx, client, "galera_01", pass); err != nil {
		return err
	}
	for _, node := range []string{"galera_02", "galera_03"} {
		if err := client.ComposeUp(ctx, g.ComposeFiles(), defaultComposeEnv(), true, node); err != nil {
			return err
		}
		if err := waitGaleraSynced(ctx, client, node, pass); err != nil {
			return err
		}
	}
	return client.ComposeUp(ctx, g.ComposeFiles(), defaultComposeEnv(), true, "haproxy_galera")
}

func waitGaleraSynced(ctx context.Context, client *docker.Client, node, pass string) error {
	env := []string{"MYSQL_PWD=" + pass}
	return waitUntil(ctx, defaultReadyTimeout, node+" Galera Synced", func() (bool, error) {
		out, err := client.Exec(ctx, node, env, "mariadb", "-uroot", "-e", "SHOW STATUS LIKE 'wsrep_local_state_comment'")
		if err != nil {
			return false, err
		}
		return strings.Contains(out, "Synced"), nil
	})
}
