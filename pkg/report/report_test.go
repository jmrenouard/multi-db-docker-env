package report

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/jmrenouard/multi-db-docker-env/pkg/bench"
	"github.com/jmrenouard/multi-db-docker-env/pkg/dbclient"
	"github.com/jmrenouard/multi-db-docker-env/pkg/runner"
)

func TestNewReport(t *testing.T) {
	r := NewReport("2.0.0")
	if r.Metadata.Version != "2.0.0" {
		t.Errorf("expected version 2.0.0, got %s", r.Metadata.Version)
	}
	if r.Metadata.Platform == "" || r.Metadata.GoVersion == "" {
		t.Error("expected non-empty platform and GoVersion")
	}
	if r.Clusters == nil || r.Benchmarks == nil || r.Steps == nil {
		t.Error("expected initialized maps and slices")
	}

	rUnknown := NewReport("")
	if rUnknown.Metadata.Version != "unknown" {
		t.Errorf("expected unknown version, got %s", rUnknown.Metadata.Version)
	}
}

func TestReport_AddAndComputeSummary(t *testing.T) {
	r := NewReport("2.0.0")

	// Nil safety
	r.AddCluster(nil)
	r.AddBenchmark("", nil)
	r.AddBenchmark("invalid", nil)

	// Add clusters
	r.AddCluster(&dbclient.ClusterHealth{
		Name:          "galera",
		Status:        dbclient.StatusHealthy,
		NodesExpected: 3,
		NodesActive:   3,
	})
	r.AddCluster(&dbclient.ClusterHealth{
		Name:          "repli",
		Status:        dbclient.StatusHealthy,
		NodesExpected: 3,
		NodesActive:   3,
	})
	r.AddCluster(&dbclient.ClusterHealth{
		Name:          "patroni",
		Status:        dbclient.StatusDegraded,
		NodesExpected: 3,
		NodesActive:   2,
	})

	// Add benchmarks
	r.AddBenchmark("galera", &bench.SysbenchResult{
		Workload: "oltp_read_write",
		Duration: 10.0,
		TPS:      1200.5,
		Latency: bench.LatencyMetrics{
			Avg: 3.2,
			P95: 5.4,
		},
	})
	r.AddBenchmark("repli", &bench.SysbenchResult{
		Workload: "oltp_read_only",
		Duration: 10.0,
		TPS:      800.0,
		Latency: bench.LatencyMetrics{
			Avg: 5.0,
			P95: 7.8,
		},
	})

	// Add runner steps
	r.AddStep(runner.StepResult{
		Name:     "InitPKI",
		Success:  true,
		Duration: 200 * time.Millisecond,
		Output:   "Certificates generated",
	})
	r.AddStep(runner.StepResult{
		Name:     "HealthCheck",
		Success:  false,
		Duration: 500 * time.Millisecond,
		Error:    errors.New("timeout connecting to node3"),
	})
	r.AddStepSummary(StepSummary{
		Name:     "CustomStep",
		Success:  true,
		Duration: 100 * time.Millisecond,
	})

	r.ComputeSummary()

	if r.Summary.TotalClusters != 3 {
		t.Errorf("expected 3 clusters, got %d", r.Summary.TotalClusters)
	}
	if r.Summary.HealthyClusters != 2 {
		t.Errorf("expected 2 healthy clusters, got %d", r.Summary.HealthyClusters)
	}
	if r.Summary.TotalTPS != 2000.5 {
		t.Errorf("expected TotalTPS 2000.5, got %f", r.Summary.TotalTPS)
	}
	expectedAvgLatency := (3.2 + 5.0) / 2.0
	if r.Summary.AvgLatencyMS != expectedAvgLatency {
		t.Errorf("expected AvgLatencyMS %f, got %f", expectedAvgLatency, r.Summary.AvgLatencyMS)
	}
	if r.Summary.TotalSteps != 3 {
		t.Errorf("expected 3 total steps, got %d", r.Summary.TotalSteps)
	}
	if r.Summary.PassedSteps != 2 {
		t.Errorf("expected 2 passed steps, got %d", r.Summary.PassedSteps)
	}
	if r.Summary.FailedSteps != 1 {
		t.Errorf("expected 1 failed step, got %d", r.Summary.FailedSteps)
	}
}

func TestReport_ToJSON_And_SaveJSON(t *testing.T) {
	r := NewReport("2.0.0")
	r.AddCluster(&dbclient.ClusterHealth{
		Name:   "galera",
		Status: dbclient.StatusHealthy,
	})

	data, err := r.ToJSON()
	if err != nil {
		t.Fatalf("ToJSON failed: %v", err)
	}

	var parsed Report
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatalf("failed to unmarshal generated JSON: %v", err)
	}
	if parsed.Metadata.Version != "2.0.0" {
		t.Errorf("unmarshaled version mismatch: got %s", parsed.Metadata.Version)
	}
	if parsed.Summary.TotalClusters != 1 {
		t.Errorf("expected 1 cluster in summary, got %d", parsed.Summary.TotalClusters)
	}

	tempDir := t.TempDir()
	jsonPath := filepath.Join(tempDir, "reports", "telemetry.json")
	if err := r.SaveJSON(jsonPath); err != nil {
		t.Fatalf("SaveJSON failed: %v", err)
	}

	readBytes, err := os.ReadFile(jsonPath)
	if err != nil {
		t.Fatalf("failed to read saved JSON file: %v", err)
	}
	if len(readBytes) == 0 {
		t.Error("saved JSON file is empty")
	}
}

func TestWriteJSONTelemetry(t *testing.T) {
	if err := WriteJSONTelemetry(nil, "some/path"); err == nil {
		t.Error("expected error when writing nil report")
	}

	r := NewReport("2.0.0")
	tempDir := t.TempDir()
	jPath := filepath.Join(tempDir, "out.json")

	if err := WriteJSONTelemetry(r, jPath); err != nil {
		t.Errorf("WriteJSONTelemetry failed: %v", err)
	}

	if _, err := os.Stat(jPath); err != nil {
		t.Errorf("JSON output file missing: %v", err)
	}
}

func TestReport_RenderHTML_And_SaveHTML(t *testing.T) {
	r := NewReport("2.0.0")
	r.AddCluster(&dbclient.ClusterHealth{
		Name:          "galera",
		Status:        dbclient.StatusHealthy,
		NodesExpected: 3,
		NodesActive:   3,
	})
	r.AddBenchmark("galera", &bench.SysbenchResult{
		Workload: "oltp_read_write",
		Duration: 10.0,
		TPS:      1500.0,
		Latency: bench.LatencyMetrics{
			Avg: 2.5,
			P95: 4.1,
		},
	})
	r.AddStep(runner.StepResult{
		Name:     "VerifyGalera",
		Success:  true,
		Duration: 150 * time.Millisecond,
		Output:   "All 3 nodes synced",
	})

	htmlStr, err := r.RenderHTML()
	if err != nil {
		t.Fatalf("RenderHTML failed: %v", err)
	}

	requiredSubstrings := []string{
		"<!DOCTYPE html>",
		"Multi-DB Docker Environment",
		"2.0.0",
		"galera",
		"HEALTHY",
		"oltp_read_write",
		"1500.00",
		"VerifyGalera",
		"PASS",
	}

	for _, sub := range requiredSubstrings {
		if !strings.Contains(htmlStr, sub) {
			t.Errorf("rendered HTML missing expected substring: %q", sub)
		}
	}

	tempDir := t.TempDir()
	htmlPath := filepath.Join(tempDir, "reports", "dashboard.html")
	if err := r.SaveHTML(htmlPath); err != nil {
		t.Fatalf("SaveHTML failed: %v", err)
	}

	savedBytes, err := os.ReadFile(htmlPath)
	if err != nil {
		t.Fatalf("failed to read saved HTML file: %v", err)
	}
	if string(savedBytes) != htmlStr {
		t.Error("saved HTML content does not match rendered string")
	}

	if err := RenderHTMLReport(nil, htmlPath); err == nil {
		t.Error("expected error rendering nil report")
	}
	if err := RenderHTMLReport(r, htmlPath); err != nil {
		t.Errorf("RenderHTMLReport failed: %v", err)
	}
}

func TestReport_EmptyData(t *testing.T) {
	r := NewReport("2.0.0")
	data, err := r.ToJSON()
	if err != nil {
		t.Fatalf("ToJSON on empty report failed: %v", err)
	}

	var parsed Report
	if err := json.Unmarshal(data, &parsed); err != nil {
		t.Fatalf("Unmarshal on empty report failed: %v", err)
	}
	if parsed.Summary.TotalClusters != 0 || parsed.Summary.TotalSteps != 0 {
		t.Error("expected 0 clusters and 0 steps in empty report")
	}

	htmlStr, err := r.RenderHTML()
	if err != nil {
		t.Fatalf("RenderHTML on empty report failed: %v", err)
	}
	if !strings.Contains(htmlStr, "No cluster status recorded") {
		t.Error("empty report should indicate no clusters")
	}
}
