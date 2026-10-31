package bench

import (
	"context"
	"encoding/json"
	"fmt"
	"regexp"
	"strconv"
	"strings"
	"time"
)

type LatencyMetrics struct {
	Min float64 `json:"min_ms"`
	Avg float64 `json:"avg_ms"`
	Max float64 `json:"max_ms"`
	P95 float64 `json:"p95_ms"`
	P99 float64 `json:"p99_ms"`
}

type QueryMetrics struct {
	Read  int64   `json:"read"`
	Write int64   `json:"write"`
	Other int64   `json:"other"`
	Total int64   `json:"total"`
	QPS   float64 `json:"qps"`
}

type SysbenchResult struct {
	Workload string         `json:"workload"`
	Duration float64        `json:"duration_sec"`
	Events   int64          `json:"total_events"`
	TPS      float64        `json:"tps"`
	Errors   int64          `json:"errors"`
	Queries  QueryMetrics   `json:"queries"`
	Latency  LatencyMetrics `json:"latency"`
	Raw      string         `json:"raw_output,omitempty"`
}

func (r *SysbenchResult) ToJSON() (string, error) {
	b, err := json.MarshalIndent(r, "", "  ")
	return string(b), err
}

type CommandExecutor interface {
	Exec(ctx context.Context, container string, env []string, cmd ...string) (string, error)
}

type SysbenchConfig struct {
	Workload  string
	Container string
	Host      string
	Port      int
	User      string
	Password  string
	Database  string
	Threads   int
	Duration  time.Duration
	Executor  CommandExecutor
}

type SysbenchRunner struct{ cfg SysbenchConfig }

func NewSysbenchRunner(cfg SysbenchConfig) *SysbenchRunner {
	if cfg.Workload == "" { cfg.Workload = "oltp_read_write" }
	if cfg.Threads <= 0 { cfg.Threads = 4 }
	if cfg.Duration <= 0 { cfg.Duration = 10 * time.Second }
	if cfg.Database == "" { cfg.Database = "sbtest" }
	return &SysbenchRunner{cfg: cfg}
}

func (r *SysbenchRunner) Run(ctx context.Context) (*SysbenchResult, error) {
	if r.cfg.Executor == nil || r.cfg.Container == "" {
		return nil, fmt.Errorf("sysbench executor and container required")
	}
	timeSec := strconv.Itoa(int(r.cfg.Duration.Seconds()))
	threads := strconv.Itoa(r.cfg.Threads)
	args := []string{"sysbench", r.cfg.Workload, "--threads=" + threads, "--time=" + timeSec, "run"}
	out, err := r.cfg.Executor.Exec(ctx, r.cfg.Container, nil, args...)
	if err != nil && out == "" {
		return nil, fmt.Errorf("sysbench execution failed: %w", err)
	}
	res, parseErr := ParseSysbenchOutput(out)
	if parseErr != nil {
		return nil, fmt.Errorf("failed to parse sysbench output: %w", parseErr)
	}
	if res.Workload == "" {
		res.Workload = r.cfg.Workload
	}
	return res, nil
}

var (
	tpsRe        = regexp.MustCompile(`transactions:\s+\d+\s+\(([\d\.]+)\s+per sec\.\)`)
	qpsRe        = regexp.MustCompile(`queries:\s+\d+\s+\(([\d\.]+)\s+per sec\.\)`)
	readRe       = regexp.MustCompile(`read:\s+(\d+)`)
	writeRe      = regexp.MustCompile(`write:\s+(\d+)`)
	otherRe      = regexp.MustCompile(`other:\s+(\d+)`)
	totalRe      = regexp.MustCompile(`total:\s+(\d+)`)
	timeRe       = regexp.MustCompile(`total time:\s+([\d\.]+)s?`)
	eventsRe     = regexp.MustCompile(`total number of events:\s+(\d+)`)
	errRe        = regexp.MustCompile(`ignored errors:\s+(\d+)`)
	latMinRe     = regexp.MustCompile(`min:\s+([\d\.]+)`)
	latAvgRe     = regexp.MustCompile(`avg:\s+([\d\.]+)`)
	latMaxRe     = regexp.MustCompile(`max:\s+([\d\.]+)`)
	latP95Re     = regexp.MustCompile(`95th percentile:\s+([\d\.]+)`)
	latP99Re     = regexp.MustCompile(`99th percentile:\s+([\d\.]+)`)
	workloadRe   = regexp.MustCompile(`Running the test with following options:[^\n]*\n.*'(.*)'`)
)

func matchFloat(re *regexp.Regexp, s string) float64 {
	if m := re.FindStringSubmatch(s); len(m) > 1 {
		v, _ := strconv.ParseFloat(m[1], 64)
		return v
	}
	return 0
}

func matchInt(re *regexp.Regexp, s string) int64 {
	if m := re.FindStringSubmatch(s); len(m) > 1 {
		v, _ := strconv.ParseInt(m[1], 10, 64)
		return v
	}
	return 0
}

func ParseSysbenchOutput(raw string) (*SysbenchResult, error) {
	if strings.TrimSpace(raw) == "" {
		return nil, fmt.Errorf("empty sysbench output")
	}

	res := &SysbenchResult{
		Duration: matchFloat(timeRe, raw),
		Events:   matchInt(eventsRe, raw),
		TPS:      matchFloat(tpsRe, raw),
		Errors:   matchInt(errRe, raw),
		Queries: QueryMetrics{
			Read:  matchInt(readRe, raw),
			Write: matchInt(writeRe, raw),
			Other: matchInt(otherRe, raw),
			Total: matchInt(totalRe, raw),
			QPS:   matchFloat(qpsRe, raw),
		},
		Latency: LatencyMetrics{
			Min: matchFloat(latMinRe, raw),
			Avg: matchFloat(latAvgRe, raw),
			Max: matchFloat(latMaxRe, raw),
			P95: matchFloat(latP95Re, raw),
			P99: matchFloat(latP99Re, raw),
		},
		Raw: raw,
	}

	if wl := workloadRe.FindStringSubmatch(raw); len(wl) > 1 {
		res.Workload = wl[1]
	}

	if res.Events == 0 && res.TPS == 0 && res.Queries.Total == 0 {
		return nil, fmt.Errorf("no valid sysbench metrics found in output")
	}

	return res, nil
}
