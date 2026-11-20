package topology

import (
	"context"
	"strings"

	"github.com/jmrenouard/multi-db-docker-env/pkg/docker"
)

// StandaloneTopology manages standalone profiled database containers with Traefik routing.
type StandaloneTopology struct{ *BaseTopology }

// NewStandaloneTopology returns the standalone multi-version topology definition.
func NewStandaloneTopology() *StandaloneTopology {
	return &StandaloneTopology{
		BaseTopology: NewBaseTopology(
			"standalone",
			"Standalone multi-version database profiles (MySQL, MariaDB, Percona, PostgreSQL, Traefik)",
			[]string{"docker-compose.yml"},
			nil,
		),
	}
}

// UpProfile starts Traefik and the requested standalone database profile (default mariadb114).
func (s *StandaloneTopology) UpProfile(ctx context.Context, client *docker.Client, profile string) error {
	p := strings.ToLower(strings.TrimSpace(profile))
	if p == "" || p == "standalone" {
		p = "mariadb114"
	}
	return client.ComposeUpProfiles(ctx, s.ComposeFiles(), []string{"traefik", p}, defaultComposeEnv(), true)
}

// Up starts Traefik and the default standalone profile (mariadb114).
func (s *StandaloneTopology) Up(ctx context.Context, client *docker.Client) error {
	return s.UpProfile(ctx, client, "mariadb114")
}

// Down stops and removes all standalone profiled containers and volumes.
func (s *StandaloneTopology) Down(ctx context.Context, client *docker.Client) error {
	return client.ComposeDownProfiles(ctx, s.ComposeFiles(), []string{"*"}, true)
}
