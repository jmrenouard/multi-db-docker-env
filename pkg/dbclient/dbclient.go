package dbclient

import (
	"context"
	"fmt"
	"net"
	"strings"
	"time"
)

type HealthStatus string

const (
	StatusHealthy   HealthStatus = "HEALTHY"
	StatusDegraded  HealthStatus = "DEGRADED"
	StatusUnhealthy HealthStatus = "UNHEALTHY"
)

type ClusterHealth struct {
	Name          string                 `json:"name"`
	Status        HealthStatus           `json:"status"`
	NodesExpected int                    `json:"nodes_expected"`
	NodesActive   int                    `json:"nodes_active"`
	Details       map[string]interface{} `json:"details,omitempty"`
}

type Verifier interface {
	Ping(ctx context.Context) error
	VerifyCluster(ctx context.Context) (*ClusterHealth, error)
	Close() error
}

type CommandExecutor interface {
	Exec(ctx context.Context, container string, env []string, cmd ...string) (string, error)
}

type Config struct {
	Name, ClusterType, Container, Host, User, Password, Database string
	Port, ExpectedNodes                                          int
	Executor                                                     CommandExecutor
	Timeout                                                      time.Duration
}

func NewVerifier(clusterType string, cfg Config) (Verifier, error) {
	lower := strings.ToLower(strings.TrimSpace(clusterType))
	if cfg.ClusterType == "" {
		cfg.ClusterType = lower
	}
	switch lower {
	case "galera", "repli", "mysql", "mariadb", "innodb":
		return NewMySQLVerifier(cfg), nil
	default:
		return nil, fmt.Errorf("unsupported cluster type: %s", clusterType)
	}
}

func tcpPing(ctx context.Context, host string, port int, timeout time.Duration) error {
	if timeout <= 0 {
		timeout = 3 * time.Second
	}
	conn, err := (&net.Dialer{Timeout: timeout}).DialContext(ctx, "tcp", fmt.Sprintf("%s:%d", host, port))
	if err != nil {
		return fmt.Errorf("tcp ping to %s:%d failed: %w", host, port, err)
	}
	return conn.Close()
}
