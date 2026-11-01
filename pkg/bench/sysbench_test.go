package bench

import (
	"context"
	"fmt"
	"strings"
	"testing"
	"time"
)

type mockExecutor struct {
	out     string
	err     error
	lastCmd []string
}

func (m *mockExecutor) Exec(ctx context.Context, container string, env []string, cmd ...string) (string, error) {
	m.lastCmd = cmd
	return m.out, m.err
}

const sampleSysbenchOutput = `SQL statistics:
    queries performed:
        read:                            14000
        write:                           4000
        other:                           2000
        total:                           20000
    transactions:                        1000   (99.85 per sec.)
    queries:                             20000  (1997.02 per sec.)
    ignored errors:                      2      (0.20 per sec.)
    reconnects:                          0      (0.00 per sec.)

General statistics:
    total time:                          10.0142s
    total number of events:              1000

Latency (ms):
         min:                                    1.23
         avg:                                    4.01
         max:                                   25.67
         95th percentile:                        7.89
         99th percentile:                       12.34
`

func TestParseSysbenchOutput_Success(t *testing.T) {
	res, err := ParseSysbenchOutput(sampleSysbenchOutput)
	if err != nil {
		t.Fatalf("unexpected parse error: %v", err)
	}
	if res.Duration != 10.0142 || res.Events != 1000 || res.TPS != 99.85 || res.Errors != 2 {
		t.Errorf("general metrics mismatch: %+v", res)
	}
	if res.Queries.Read != 14000 || res.Queries.Write != 4000 || res.Queries.Other != 2000 || res.Queries.Total != 20000 || res.Queries.QPS != 1997.02 {
		t.Errorf("queries mismatch: %+v", res.Queries)
	}
	if res.Latency.Min != 1.23 || res.Latency.Avg != 4.01 || res.Latency.Max != 25.67 || res.Latency.P95 != 7.89 || res.Latency.P99 != 12.34 {
		t.Errorf("latency mismatch: %+v", res.Latency)
	}

	jsonStr, err := res.ToJSON()
	if err != nil || !strings.Contains(jsonStr, `"tps": 99.85`) {
		t.Errorf("ToJSON failed: %v, json: %s", err, jsonStr)
	}
}

func TestParseSysbenchOutput_Errors(t *testing.T) {
	for _, raw := range []string{"", "   \n\t  ", "random output without metrics"} {
		if _, err := ParseSysbenchOutput(raw); err == nil {
			t.Fatalf("expected error for %q, got nil", raw)
		}
	}
}

func TestSysbenchRunner_Run(t *testing.T) {
	mock := &mockExecutor{out: sampleSysbenchOutput}
	runner := NewSysbenchRunner(SysbenchConfig{
		Workload:  "oltp_read_write",
		Container: "node1",
		User:      "root",
		Password:  "secret",
		Host:      "127.0.0.1",
		Port:      3306,
		Database:  "sbtest",
		Threads:   4,
		Duration:  5 * time.Second,
		Executor:  mock,
	})
	res, err := runner.Run(context.Background())
	if err != nil || res.Workload != "oltp_read_write" || res.TPS != 99.85 {
		t.Fatalf("Run failed: %v, res: %+v", err, res)
	}

	cmdStr := strings.Join(mock.lastCmd, " ")
	for _, expected := range []string{
		"--db-driver=mysql",
		"--mysql-user=root",
		"--mysql-password=secret",
		"--mysql-host=127.0.0.1",
		"--mysql-port=3306",
		"--mysql-db=sbtest",
	} {
		if !strings.Contains(cmdStr, expected) {
			t.Errorf("expected cmd to contain %q, got: %s", expected, cmdStr)
		}
	}

	runnerNil := NewSysbenchRunner(SysbenchConfig{Container: "node1"})
	if _, err := runnerNil.Run(context.Background()); err == nil {
		t.Fatal("expected error with nil executor")
	}

	runnerErr := NewSysbenchRunner(SysbenchConfig{
		Container: "node1",
		Executor:  &mockExecutor{err: fmt.Errorf("container died")},
	})
	if _, err := runnerErr.Run(context.Background()); err == nil {
		t.Fatal("expected error on exec failure")
	}
}
