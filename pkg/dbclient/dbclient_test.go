package dbclient

import (
	"context"
	"fmt"
	"net"
	"testing"
	"time"
)

type mockExecutor struct {
	response func(ctx context.Context, c string, env []string, cmd ...string) (string, error)
}

func (m *mockExecutor) Exec(ctx context.Context, c string, env []string, cmd ...string) (string, error) {
	if m.response != nil {
		return m.response(ctx, c, env, cmd...)
	}
	return "", nil
}

func TestMySQLVerifier_VerifyCluster(t *testing.T) {
	ctx := context.Background()
	cases := []struct {
		name, topo, out string
		expStatus       HealthStatus
		expNodes        int
	}{
		{"galera_healthy", "galera", "wsrep_cluster_size 3\nwsrep_ready ON\nwsrep_connected ON\nwsrep_cluster_status Primary\n", StatusHealthy, 3},
		{"galera_degraded", "galera", "wsrep_cluster_size 2\nwsrep_ready ON\nwsrep_connected ON\nwsrep_cluster_status Primary\n", StatusDegraded, 3},
		{"galera_unhealthy", "galera", "wsrep_cluster_size 0\nwsrep_ready OFF\n", StatusUnhealthy, 3},
		{"repli_healthy", "repli", "Slave_IO_Running: Yes\nSlave_SQL_Running: Yes\nSeconds_Behind_Master: 0\n", StatusHealthy, 2},
		{"repli_degraded", "repli", "Slave_IO_Running: Yes\nSlave_SQL_Running: Yes\nSeconds_Behind_Master: 120\n", StatusDegraded, 2},
		{"repli_unhealthy", "repli", "Slave_IO_Running: No\n", StatusUnhealthy, 2},
		{"innodb_healthy", "innodb", "ONLINE 3\n", StatusHealthy, 3},
		{"innodb_degraded", "innodb", "ONLINE 1\n", StatusDegraded, 3},
		{"standalone_ok", "standalone", "1\n", StatusHealthy, 1},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			exec := &mockExecutor{response: func(ctx context.Context, c string, e []string, cmd ...string) (string, error) {
				return tc.out, nil
			}}
			v := NewMySQLVerifier(Config{ClusterType: tc.topo, Container: "db", ExpectedNodes: tc.expNodes, Executor: exec})
			h, err := v.VerifyCluster(ctx)
			if err != nil || h.Status != tc.expStatus {
				t.Fatalf("%s failed: h=%v err=%v", tc.name, h, err)
			}
			_ = v.Close()
		})
	}
	t.Run("query_error", func(t *testing.T) {
		exec := &mockExecutor{response: func(ctx context.Context, c string, e []string, cmd ...string) (string, error) {
			return "", fmt.Errorf("connection failed")
		}}
		v := NewMySQLVerifier(Config{ClusterType: "galera", Container: "db", Executor: exec})
		if h, err := v.VerifyCluster(ctx); err == nil || h.Status != StatusUnhealthy {
			t.Fatalf("expected failure, got h=%v err=%v", h, err)
		}
	})
}

func TestMySQLVerifier_Ping(t *testing.T) {
	ctx := context.Background()
	e := &mockExecutor{response: func(ctx context.Context, c string, env []string, cmd ...string) (string, error) {
		return "mysqld is alive\n", nil
	}}
	if err := NewMySQLVerifier(Config{Container: "db", Executor: e}).Ping(ctx); err != nil {
		t.Fatal(err)
	}
	bad := &mockExecutor{response: func(ctx context.Context, c string, env []string, cmd ...string) (string, error) {
		return "", fmt.Errorf("fail")
	}}
	if err := NewMySQLVerifier(Config{Container: "db", Executor: bad}).Ping(ctx); err == nil {
		t.Fatal("expected error")
	}
}

func TestTCPPing(t *testing.T) {
	ctx := context.Background()
	l, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer l.Close()
	if err := tcpPing(ctx, "127.0.0.1", l.Addr().(*net.TCPAddr).Port, time.Second); err != nil {
		t.Fatal(err)
	}
	if err := tcpPing(ctx, "127.0.0.1", 64998, 50*time.Millisecond); err == nil {
		t.Fatal("expected err")
	}
}

func TestNewVerifier_Factory(t *testing.T) {
	for _, vt := range []string{"galera", "repli", "mysql", "mariadb", "innodb"} {
		if v, err := NewVerifier(vt, Config{}); err != nil || v == nil {
			t.Fatalf("err: %v", err)
		}
	}
	if _, err := NewVerifier("unknown", Config{}); err == nil {
		t.Fatal("expected err")
	}
}
