package dbclient

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
)

type PostgresVerifier struct{ cfg Config }

func NewPostgresVerifier(cfg Config) *PostgresVerifier {
	if cfg.User == "" { cfg.User = "postgres" }
	if cfg.Database == "" { cfg.Database = "postgres" }
	if cfg.Port <= 0 { cfg.Port = 5432 }
	if cfg.ExpectedNodes <= 0 {
		switch strings.ToLower(cfg.ClusterType) {
		case "patroni": cfg.ExpectedNodes = 3
		case "pgpool": cfg.ExpectedNodes = 2
		default: cfg.ExpectedNodes = 1
		}
	}
	return &PostgresVerifier{cfg: cfg}
}

func (p *PostgresVerifier) Ping(ctx context.Context) error {
	if p.cfg.Executor != nil && p.cfg.Container != "" {
		out, err := p.cfg.Executor.Exec(ctx, p.cfg.Container, nil, "pg_isready", "-h", "localhost", "-p", strconv.Itoa(p.cfg.Port), "-U", p.cfg.User)
		if err == nil && strings.Contains(strings.ToLower(out), "accepting connections") {
			return nil
		}
		if p.cfg.Host == "" { return fmt.Errorf("postgres ping failed in container %s", p.cfg.Container) }
	}
	if p.cfg.Host != "" && p.cfg.Port > 0 { return tcpPing(ctx, p.cfg.Host, p.cfg.Port, p.cfg.Timeout) }
	return fmt.Errorf("no container or host specified for postgres ping")
}

func (p *PostgresVerifier) execQuery(ctx context.Context, q string) (string, error) {
	var env []string
	if p.cfg.Password != "" { env = []string{"PGPASSWORD=" + p.cfg.Password} }
	return p.cfg.Executor.Exec(ctx, p.cfg.Container, env, "psql", "-U", p.cfg.User, "-d", p.cfg.Database, "-c", q)
}

func (p *PostgresVerifier) verifyPatroni(ctx context.Context, h *ClusterHealth) error {
	out, err := p.cfg.Executor.Exec(ctx, p.cfg.Container, nil, "patronictl", "-c", "/etc/patroni.yml", "list", "-f", "json")
	if err != nil {
		out, err = p.cfg.Executor.Exec(ctx, p.cfg.Container, nil, "patronictl", "-c", "/etc/patroni.yml", "list")
	}
	if err != nil { return fmt.Errorf("patronictl failed: %w", err) }
	var members []struct{ Role, State string }
	hasLeader, active := false, 0
	if json.Unmarshal([]byte(out), &members) == nil && len(members) > 0 {
		for _, m := range members {
			if strings.EqualFold(m.State, "running") {
				active++
				if strings.EqualFold(m.Role, "Leader") { hasLeader = true }
			}
		}
	} else {
		for _, l := range strings.Split(out, "\n") {
			if strings.Contains(strings.ToLower(l), "running") {
				active++
				if strings.Contains(strings.ToLower(l), "leader") { hasLeader = true }
			}
		}
	}
	h.NodesActive = active
	if hasLeader && active >= p.cfg.ExpectedNodes { h.Status = StatusHealthy } else if hasLeader && active > 0 { h.Status = StatusDegraded }
	return nil
}

func (p *PostgresVerifier) verifyPgPool(ctx context.Context, h *ClusterHealth) error {
	out, err := p.execQuery(ctx, "SHOW POOL_NODES;")
	if err != nil { return fmt.Errorf("show pool_nodes failed: %w", err) }
	up := 0
	for _, l := range strings.Split(out, "\n") {
		if parts := strings.Split(l, "|"); len(parts) >= 4 {
			if st := strings.ToLower(strings.TrimSpace(parts[3])); st == "up" || st == "available" { up++ }
		}
	}
	h.NodesActive = up
	if up >= p.cfg.ExpectedNodes { h.Status = StatusHealthy } else if up > 0 { h.Status = StatusDegraded }
	return nil
}

func (p *PostgresVerifier) VerifyCluster(ctx context.Context) (*ClusterHealth, error) {
	name := p.cfg.Name
	if name == "" { name = p.cfg.ClusterType }
	h := &ClusterHealth{Name: name, Status: StatusUnhealthy, NodesExpected: p.cfg.ExpectedNodes, Details: make(map[string]interface{})}
	if p.cfg.Executor == nil || p.cfg.Container == "" {
		if err := p.Ping(ctx); err != nil { return h, err }
		h.Status, h.NodesActive = StatusHealthy, 1
		return h, nil
	}
	var err error
	switch strings.ToLower(p.cfg.ClusterType) {
	case "patroni": err = p.verifyPatroni(ctx, h)
	case "pgpool": err = p.verifyPgPool(ctx, h)
	default:
		out, qErr := p.execQuery(ctx, "SELECT 1;")
		if qErr != nil || !strings.Contains(out, "1") { return h, fmt.Errorf("standalone check failed: %w", qErr) }
		h.Status, h.NodesActive = StatusHealthy, 1
	}
	return h, err
}

func (p *PostgresVerifier) Close() error { return nil }
