package dbclient

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
)

type MongoVerifier struct{ cfg Config }

func NewMongoVerifier(cfg Config) *MongoVerifier {
	if cfg.Port <= 0 { cfg.Port = 27017 }
	if cfg.ExpectedNodes <= 0 {
		if strings.Contains(strings.ToLower(cfg.ClusterType), "mongo") || strings.EqualFold(cfg.ClusterType, "replicaset") {
			cfg.ExpectedNodes = 3
		} else {
			cfg.ExpectedNodes = 1
		}
	}
	return &MongoVerifier{cfg: cfg}
}

func (m *MongoVerifier) execEval(ctx context.Context, expr string) (string, error) {
	var out string
	var err error
	for _, bin := range []string{"mongosh", "mongo"} {
		out, err = m.cfg.Executor.Exec(ctx, m.cfg.Container, nil, bin, "--eval", expr, "--quiet")
		if err == nil { return out, nil }
	}
	return out, err
}

func (m *MongoVerifier) Ping(ctx context.Context) error {
	if m.cfg.Executor != nil && m.cfg.Container != "" {
		out, err := m.execEval(ctx, "db.runCommand({ping: 1}).ok")
		if err == nil && strings.Contains(out, "1") { return nil }
		if m.cfg.Host == "" { return fmt.Errorf("mongo ping failed in container %s", m.cfg.Container) }
	}
	if m.cfg.Host != "" && m.cfg.Port > 0 { return tcpPing(ctx, m.cfg.Host, m.cfg.Port, m.cfg.Timeout) }
	return fmt.Errorf("no container or host specified for mongo ping")
}

func (m *MongoVerifier) VerifyCluster(ctx context.Context) (*ClusterHealth, error) {
	name := m.cfg.Name
	if name == "" { name = m.cfg.ClusterType }
	h := &ClusterHealth{Name: name, Status: StatusUnhealthy, NodesExpected: m.cfg.ExpectedNodes, Details: make(map[string]interface{})}
	if m.cfg.Executor == nil || m.cfg.Container == "" {
		if err := m.Ping(ctx); err != nil { return h, err }
		h.Status, h.NodesActive = StatusHealthy, 1
		return h, nil
	}
	out, err := m.execEval(ctx, "JSON.stringify(rs.status())")
	if err != nil {
		if pingErr := m.Ping(ctx); pingErr == nil {
			h.Status, h.NodesActive = StatusHealthy, 1
			return h, nil
		}
		return h, fmt.Errorf("mongo status query failed: %w", err)
	}

	start, end := strings.Index(out, "{"), strings.LastIndex(out, "}")
	if start >= 0 && end > start { out = out[start : end+1] }

	var status struct {
		Members []struct {
			Health   float64 `json:"health"`
			State    int     `json:"state"`
			StateStr string  `json:"stateStr"`
		} `json:"members"`
	}
	if err := json.Unmarshal([]byte(out), &status); err != nil {
		return h, fmt.Errorf("failed to parse rs.status: %w", err)
	}

	active, hasPrimary := 0, false
	for _, mem := range status.Members {
		if mem.Health == 1 && (mem.State == 1 || mem.State == 2 || mem.State == 7) {
			active++
			if mem.State == 1 || strings.EqualFold(mem.StateStr, "PRIMARY") { hasPrimary = true }
		}
	}
	h.NodesActive = active
	if hasPrimary && active >= m.cfg.ExpectedNodes {
		h.Status = StatusHealthy
	} else if hasPrimary && active > 0 {
		h.Status = StatusDegraded
	}
	return h, nil
}

func (m *MongoVerifier) Close() error { return nil }
