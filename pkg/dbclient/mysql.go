package dbclient

import (
	"context"
	"fmt"
	"strconv"
	"strings"
)

type MySQLVerifier struct{ cfg Config }

func NewMySQLVerifier(cfg Config) *MySQLVerifier {
	if cfg.User == "" { cfg.User = "root" }
	if cfg.Port <= 0 { cfg.Port = 3306 }
	if cfg.ExpectedNodes <= 0 {
		switch strings.ToLower(cfg.ClusterType) {
		case "galera", "innodb": cfg.ExpectedNodes = 3
		case "repli": cfg.ExpectedNodes = 2
		default: cfg.ExpectedNodes = 1
		}
	}
	return &MySQLVerifier{cfg: cfg}
}

func (m *MySQLVerifier) Ping(ctx context.Context) error {
	if m.cfg.Executor != nil && m.cfg.Container != "" {
		env := []string{"MYSQL_PWD=" + m.cfg.Password}
		for _, bin := range []string{"mariadb-admin", "mysqladmin"} {
			out, err := m.cfg.Executor.Exec(ctx, m.cfg.Container, env, bin, "-u"+m.cfg.User, "ping")
			if err == nil && strings.Contains(strings.ToLower(out), "alive") { return nil }
		}
		if m.cfg.Host == "" { return fmt.Errorf("mysql ping failed in container %s", m.cfg.Container) }
	}
	if m.cfg.Host != "" && m.cfg.Port > 0 { return tcpPing(ctx, m.cfg.Host, m.cfg.Port, m.cfg.Timeout) }
	return fmt.Errorf("no container or host specified for mysql ping")
}

func (m *MySQLVerifier) execQuery(ctx context.Context, q string) (string, error) {
	env := []string{"MYSQL_PWD=" + m.cfg.Password}
	out, err := m.cfg.Executor.Exec(ctx, m.cfg.Container, env, "mariadb", "-u"+m.cfg.User, "-sN", "-e", q)
	if err != nil {
		out, err = m.cfg.Executor.Exec(ctx, m.cfg.Container, env, "mysql", "-u"+m.cfg.User, "-sN", "-e", q)
	}
	return out, err
}

func (m *MySQLVerifier) verifyGalera(ctx context.Context, h *ClusterHealth) error {
	out, err := m.execQuery(ctx, "SHOW STATUS LIKE 'wsrep_%';")
	if err != nil { return fmt.Errorf("galera query failed: %w", err) }
	kv := parseKeyValue(out)
	size, _ := strconv.Atoi(kv["wsrep_cluster_size"])
	h.NodesActive = size
	if size >= m.cfg.ExpectedNodes && strings.EqualFold(kv["wsrep_ready"], "ON") && kv["wsrep_cluster_status"] == "Primary" {
		h.Status = StatusHealthy
	} else if size > 0 && strings.EqualFold(kv["wsrep_ready"], "ON") {
		h.Status = StatusDegraded
	}
	return nil
}

func (m *MySQLVerifier) verifyRepli(ctx context.Context, h *ClusterHealth) error {
	out, err := m.execQuery(ctx, "SHOW REPLICA STATUS\\G;")
	if err != nil || strings.TrimSpace(out) == "" { out, err = m.execQuery(ctx, "SHOW SLAVE STATUS\\G;") }
	if err != nil { return fmt.Errorf("replication query failed: %w", err) }
	kv := parseVertical(out)
	io, sql := kv["Slave_IO_Running"], kv["Slave_SQL_Running"]
	if io == "" { io, sql = kv["Replica_IO_Running"], kv["Replica_SQL_Running"] }
	lag, _ := strconv.ParseInt(kv["Seconds_Behind_Master"], 10, 64)
	if strings.EqualFold(io, "Yes") && strings.EqualFold(sql, "Yes") {
		h.NodesActive = m.cfg.ExpectedNodes
		if lag < 60 { h.Status = StatusHealthy } else { h.Status = StatusDegraded }
	} else if strings.EqualFold(io, "Connecting") {
		h.Status, h.NodesActive = StatusDegraded, 1
	} else {
		h.Status, h.NodesActive = StatusUnhealthy, 1
	}
	return nil
}

func (m *MySQLVerifier) verifyInnoDB(ctx context.Context, h *ClusterHealth) error {
	out, err := m.execQuery(ctx, "SELECT MEMBER_STATE, COUNT(*) FROM performance_schema.replication_group_members GROUP BY MEMBER_STATE;")
	if err != nil { return fmt.Errorf("innodb query failed: %w", err) }
	for _, l := range strings.Split(out, "\n") {
		if f := strings.Fields(l); len(f) >= 2 && strings.EqualFold(f[0], "ONLINE") {
			c, _ := strconv.Atoi(f[1])
			h.NodesActive += c
		}
	}
	if h.NodesActive >= m.cfg.ExpectedNodes { h.Status = StatusHealthy } else if h.NodesActive > 0 { h.Status = StatusDegraded }
	return nil
}

func (m *MySQLVerifier) VerifyCluster(ctx context.Context) (*ClusterHealth, error) {
	name := m.cfg.Name
	if name == "" { name = m.cfg.ClusterType }
	h := &ClusterHealth{Name: name, Status: StatusUnhealthy, NodesExpected: m.cfg.ExpectedNodes, Details: make(map[string]interface{})}
	if m.cfg.Executor == nil || m.cfg.Container == "" {
		if err := m.Ping(ctx); err != nil { return h, err }
		h.Status, h.NodesActive = StatusHealthy, 1
		return h, nil
	}
	var err error
	switch strings.ToLower(m.cfg.ClusterType) {
	case "galera": err = m.verifyGalera(ctx, h)
	case "repli": err = m.verifyRepli(ctx, h)
	case "innodb": err = m.verifyInnoDB(ctx, h)
	default:
		out, qErr := m.execQuery(ctx, "SELECT 1;")
		if qErr != nil || strings.TrimSpace(out) != "1" { return h, fmt.Errorf("standalone check failed: %w", qErr) }
		h.Status, h.NodesActive = StatusHealthy, 1
	}
	return h, err
}

func (m *MySQLVerifier) Close() error { return nil }

func parseKeyValue(raw string) map[string]string {
	res := make(map[string]string)
	for _, l := range strings.Split(raw, "\n") {
		if f := strings.Fields(l); len(f) >= 2 { res[f[0]] = f[1] }
	}
	return res
}

func parseVertical(raw string) map[string]string {
	res := make(map[string]string)
	for _, l := range strings.Split(raw, "\n") {
		if idx := strings.Index(l, ":"); idx > 0 { res[strings.TrimSpace(l[:idx])] = strings.TrimSpace(l[idx+1:]) }
	}
	return res
}
