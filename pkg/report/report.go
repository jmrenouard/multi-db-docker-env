package report

import (
	"bytes"
	"embed"
	"encoding/json"
	"fmt"
	"html/template"
	"os"
	"path/filepath"
	"runtime"
	"time"

	"github.com/jmrenouard/multi-db-docker-env/pkg/bench"
	"github.com/jmrenouard/multi-db-docker-env/pkg/dbclient"
	"github.com/jmrenouard/multi-db-docker-env/pkg/runner"
)

//go:embed templates/report.html
var templateFS embed.FS

// Metadata captures the execution context and environment.
type Metadata struct {
	Timestamp time.Time `json:"timestamp"`
	Version   string    `json:"version"`
	Platform  string    `json:"platform"`
	GoVersion string    `json:"go_version"`
}

// Summary provides high-level aggregation KPIs.
type Summary struct {
	TotalClusters   int     `json:"total_clusters"`
	HealthyClusters int     `json:"healthy_clusters"`
	TotalTPS        float64 `json:"total_tps"`
	AvgLatencyMS    float64 `json:"avg_latency_ms"`
	TotalSteps      int     `json:"total_steps"`
	PassedSteps     int     `json:"passed_steps"`
	FailedSteps     int     `json:"failed_steps"`
}

// StepSummary is a serializable representation of a runner step result.
type StepSummary struct {
	Name     string        `json:"name"`
	Success  bool          `json:"success"`
	Duration time.Duration `json:"duration"`
	Output   string        `json:"output,omitempty"`
	Error    string        `json:"error,omitempty"`
}

// Report aggregates cluster health, benchmark metrics, and pipeline steps.
type Report struct {
	Metadata   Metadata                           `json:"metadata"`
	Summary    Summary                            `json:"summary"`
	Clusters   map[string]*dbclient.ClusterHealth `json:"clusters"`
	Benchmarks map[string]*bench.SysbenchResult   `json:"benchmarks"`
	Steps      []StepSummary                      `json:"steps"`
}

// NewReport constructs an empty Report with system metadata populated.
func NewReport(version string) *Report {
	if version == "" {
		version = "unknown"
	}
	return &Report{
		Metadata: Metadata{
			Timestamp: time.Now().UTC(),
			Version:   version,
			Platform:  fmt.Sprintf("%s/%s", runtime.GOOS, runtime.GOARCH),
			GoVersion: runtime.Version(),
		},
		Clusters:   make(map[string]*dbclient.ClusterHealth),
		Benchmarks: make(map[string]*bench.SysbenchResult),
		Steps:      make([]StepSummary, 0),
	}
}

// AddCluster registers or updates a cluster verification status.
func (r *Report) AddCluster(health *dbclient.ClusterHealth) {
	if health == nil {
		return
	}
	if r.Clusters == nil {
		r.Clusters = make(map[string]*dbclient.ClusterHealth)
	}
	r.Clusters[health.Name] = health
}

// AddBenchmark registers sysbench benchmark results for a target topology.
func (r *Report) AddBenchmark(name string, result *bench.SysbenchResult) {
	if result == nil || name == "" {
		return
	}
	if r.Benchmarks == nil {
		r.Benchmarks = make(map[string]*bench.SysbenchResult)
	}
	r.Benchmarks[name] = result
}

// AddStep appends a runner StepResult.
func (r *Report) AddStep(step runner.StepResult) {
	errStr := ""
	if step.Error != nil {
		errStr = step.Error.Error()
	}
	r.Steps = append(r.Steps, StepSummary{
		Name:     step.Name,
		Success:  step.Success,
		Duration: step.Duration,
		Output:   step.Output,
		Error:    errStr,
	})
}

// AddStepSummary appends an explicit StepSummary.
func (r *Report) AddStepSummary(step StepSummary) {
	r.Steps = append(r.Steps, step)
}

// ComputeSummary recalculates summary KPIs based on current data.
func (r *Report) ComputeSummary() {
	r.Summary = Summary{
		TotalClusters: len(r.Clusters),
		TotalSteps:    len(r.Steps),
	}
	for _, c := range r.Clusters {
		if c != nil && c.Status == dbclient.StatusHealthy {
			r.Summary.HealthyClusters++
		}
	}
	var totalLatency float64
	for _, b := range r.Benchmarks {
		if b != nil {
			r.Summary.TotalTPS += b.TPS
			totalLatency += b.Latency.Avg
		}
	}
	if len(r.Benchmarks) > 0 {
		r.Summary.AvgLatencyMS = totalLatency / float64(len(r.Benchmarks))
	}
	for _, s := range r.Steps {
		if s.Success {
			r.Summary.PassedSteps++
		} else {
			r.Summary.FailedSteps++
		}
	}
}

// ToJSON serializes the report into formatted JSON bytes.
func (r *Report) ToJSON() ([]byte, error) {
	r.ComputeSummary()
	return json.MarshalIndent(r, "", "  ")
}

// SaveJSON writes formatted JSON to the specified destination path.
func (r *Report) SaveJSON(filePath string) error {
	data, err := r.ToJSON()
	if err != nil {
		return fmt.Errorf("failed to serialize report to JSON: %w", err)
	}
	if dir := filepath.Dir(filePath); dir != "" && dir != "." {
		if err := os.MkdirAll(dir, 0755); err != nil {
			return fmt.Errorf("failed to create directory %s: %w", dir, err)
		}
	}
	return os.WriteFile(filePath, data, 0644)
}

// WriteJSONTelemetry writes telemetry JSON to disk (helper function).
func WriteJSONTelemetry(report *Report, filePath string) error {
	if report == nil {
		return fmt.Errorf("report cannot be nil")
	}
	return report.SaveJSON(filePath)
}

// RenderHTML executes the embedded HTML template against the report data.
func (r *Report) RenderHTML() (string, error) {
	r.ComputeSummary()
	tmpl, err := template.ParseFS(templateFS, "templates/report.html")
	if err != nil {
		return "", fmt.Errorf("failed to parse embedded report template: %w", err)
	}
	var buf bytes.Buffer
	if err := tmpl.Execute(&buf, r); err != nil {
		return "", fmt.Errorf("failed to execute report template: %w", err)
	}
	return buf.String(), nil
}

// SaveHTML renders and saves the HTML report to disk.
func (r *Report) SaveHTML(filePath string) error {
	htmlStr, err := r.RenderHTML()
	if err != nil {
		return err
	}
	if dir := filepath.Dir(filePath); dir != "" && dir != "." {
		if err := os.MkdirAll(dir, 0755); err != nil {
			return fmt.Errorf("failed to create directory %s: %w", dir, err)
		}
	}
	return os.WriteFile(filePath, []byte(htmlStr), 0644)
}

// RenderHTMLReport renders and writes HTML report to disk (helper function).
func RenderHTMLReport(report *Report, filePath string) error {
	if report == nil {
		return fmt.Errorf("report cannot be nil")
	}
	return report.SaveHTML(filePath)
}
