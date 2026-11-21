package dbclient

import (
	"context"
	"fmt"
	"strings"
	"testing"
)

func TestPostgresVerifier_VerifyCluster(t *testing.T) {
	ctx := context.Background()
	cases := []struct {
		name, topo, out, wantCmd string
		expStatus                HealthStatus
		expNodes                 int
	}{
		{"patroni_healthy", "patroni", `[{"Role":"Leader","State":"running"},{"Role":"Replica","State":"running"}]`, "patronictl", StatusHealthy, 2},
		{"patroni_degraded", "patroni", `[{"Role":"Leader","State":"running"},{"Role":"Replica","State":"stopped"}]`, "patronictl", StatusDegraded, 2},
		{"patroni_table", "patroni", "|p1|Leader|running\n|p2|Replica|stopped", "patronictl", StatusDegraded, 2},
		{"patroni_unhealthy", "patroni", `[{"Role":"Replica","State":"stopped"}]`, "patronictl", StatusUnhealthy, 2},
		{"pgpool_healthy", "pgpool", "0|h1|5432|up\n1|h2|5432|up\n", "-h 127.0.0.1 -p 9999", StatusHealthy, 2},
		{"pgpool_degraded", "pgpool", "0|h1|5432|up\n1|h2|5432|down\n", "-h 127.0.0.1 -p 9999", StatusDegraded, 2},
		{"pgpool_unhealthy", "pgpool", "0|h1|5432|down\n", "-h 127.0.0.1 -p 9999", StatusUnhealthy, 2},
		{"cockroach_healthy", "cockroach", "count\n3\n", "/cockroach/cockroach sql", StatusHealthy, 3},
		{"cockroach_degraded", "cockroach", "count\n2\n", "/cockroach/cockroach sql", StatusDegraded, 3},
		{"yugabyte_healthy", "yugabyte", "3\n", "/home/yugabyte/bin/ysqlsh", StatusHealthy, 3},
		{"yugabyte_degraded", "yugabyte", "1\n", "/home/yugabyte/bin/ysqlsh", StatusDegraded, 3},
		{"standalone_ok", "postgres", "1\n", "psql -U postgres", StatusHealthy, 1},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			exec := &mockExecutor{response: func(ctx context.Context, c string, e []string, cmd ...string) (string, error) {
				if joined := strings.Join(cmd, " "); !strings.Contains(joined, tc.wantCmd) {
					t.Fatalf("%s: got cmd %q, want substring %q", tc.name, joined, tc.wantCmd)
				}
				return tc.out, nil
			}}
			v := NewPostgresVerifier(Config{ClusterType: tc.topo, Container: "pg", ExpectedNodes: tc.expNodes, Executor: exec})
			h, err := v.VerifyCluster(ctx)
			if err != nil || h.Status != tc.expStatus {
				t.Fatalf("%s failed: h=%v err=%v", tc.name, h, err)
			}
			_ = v.Close()
		})
	}
	t.Run("patronictl_error", func(t *testing.T) {
		exec := &mockExecutor{response: func(ctx context.Context, c string, e []string, cmd ...string) (string, error) {
			return "", fmt.Errorf("cmd failed")
		}}
		v := NewPostgresVerifier(Config{ClusterType: "patroni", Container: "pg", Executor: exec})
		if h, err := v.VerifyCluster(ctx); err == nil || h.Status != StatusUnhealthy {
			t.Fatalf("expected error, got h=%v err=%v", h, err)
		}
	})
}

func TestPostgresVerifier_Ping(t *testing.T) {
	ctx := context.Background()
	e := &mockExecutor{response: func(ctx context.Context, c string, env []string, cmd ...string) (string, error) {
		return "accepting connections\n", nil
	}}
	if err := NewPostgresVerifier(Config{Container: "pg", Executor: e}).Ping(ctx); err != nil {
		t.Fatal(err)
	}
	bad := &mockExecutor{response: func(ctx context.Context, c string, env []string, cmd ...string) (string, error) { return "", fmt.Errorf("fail") }}
	if err := NewPostgresVerifier(Config{Container: "pg", Executor: bad}).Ping(ctx); err == nil {
		t.Fatal("expected error")
	}
}

func TestMongoVerifier_VerifyCluster(t *testing.T) {
	ctx := context.Background()
	cases := []struct {
		name, out string
		expStatus HealthStatus
		expNodes  int
	}{
		{"healthy", `{"members":[{"health":1,"state":1},{"health":1,"state":2}]}`, StatusHealthy, 2},
		{"degraded", `{"members":[{"health":1,"state":1},{"health":0,"state":2}]}`, StatusDegraded, 2},
		{"unhealthy", `{"members":[{"health":1,"state":2}]}`, StatusUnhealthy, 2},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			exec := &mockExecutor{response: func(ctx context.Context, c string, e []string, cmd ...string) (string, error) {
				return tc.out, nil
			}}
			v := NewMongoVerifier(Config{ClusterType: "mongo", Container: "m", ExpectedNodes: tc.expNodes, Executor: exec})
			h, err := v.VerifyCluster(ctx)
			if err != nil || h.Status != tc.expStatus {
				t.Fatalf("%s failed: h=%v err=%v", tc.name, h, err)
			}
			_ = v.Close()
		})
	}
	t.Run("mongo_standalone_fallback", func(t *testing.T) {
		exec := &mockExecutor{response: func(ctx context.Context, c string, e []string, cmd ...string) (string, error) {
			for _, arg := range cmd {
				if arg == "db.runCommand({ping: 1}).ok" {
					return "1\n", nil
				}
			}
			return "", fmt.Errorf("not a replicaset")
		}}
		v := NewMongoVerifier(Config{ClusterType: "mongo", Container: "m", Executor: exec})
		if h, err := v.VerifyCluster(ctx); err != nil || h.Status != StatusHealthy {
			t.Fatalf("expected fallback healthy, got h=%v err=%v", h, err)
		}
	})
}

func TestMongoVerifier_Ping(t *testing.T) {
	ctx := context.Background()
	e := &mockExecutor{response: func(ctx context.Context, c string, env []string, cmd ...string) (string, error) { return "1\n", nil }}
	if err := NewMongoVerifier(Config{Container: "m", Executor: e}).Ping(ctx); err != nil {
		t.Fatal(err)
	}
	bad := &mockExecutor{response: func(ctx context.Context, c string, env []string, cmd ...string) (string, error) { return "", fmt.Errorf("fail") }}
	if err := NewMongoVerifier(Config{Container: "m", Executor: bad}).Ping(ctx); err == nil {
		t.Fatal("expected error")
	}
}

func TestNewVerifier_FactoryAll(t *testing.T) {
	for _, vt := range []string{"patroni", "pgpool", "postgres", "mongo", "mongo8", "replicaset"} {
		if v, err := NewVerifier(vt, Config{}); err != nil || v == nil {
			t.Fatalf("failed for %s: %v", vt, err)
		}
	}
}
