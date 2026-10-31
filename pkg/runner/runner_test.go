package runner

import (
	"context"
	"fmt"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

func TestPipeline_SequentialAndConcurrent(t *testing.T) {
	ctx := context.Background()

	t.Run("concurrent parallel speedup", func(t *testing.T) {
		start := time.Now()
		p := NewPipeline(
			Step{
				Name: "A",
				Run: func(ctx context.Context) error {
					time.Sleep(50 * time.Millisecond)
					return nil
				},
			},
			Step{
				Name: "B",
				Run: func(ctx context.Context) error {
					time.Sleep(50 * time.Millisecond)
					return nil
				},
			},
		)
		results, err := p.Run(ctx)
		dur := time.Since(start)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if len(results) != 2 || !results[0].Success || !results[1].Success {
			t.Fatalf("expected 2 successful results: %+v", results)
		}
		if dur >= 95*time.Millisecond {
			t.Errorf("expected parallel execution (<95ms), took %v", dur)
		}
	})

	t.Run("dependency ordering", func(t *testing.T) {
		var order []string
		var mu sync.Mutex
		p := NewPipeline(
			Step{
				Name: "A",
				Run: func(ctx context.Context) error {
					mu.Lock()
					order = append(order, "A")
					mu.Unlock()
					return nil
				},
			},
			Step{
				Name:         "B",
				Dependencies: []string{"A"},
				Run: func(ctx context.Context) error {
					mu.Lock()
					order = append(order, "B")
					mu.Unlock()
					return nil
				},
			},
		)
		results, err := p.Run(ctx)
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if len(results) != 2 || results[0].Name != "A" || results[1].Name != "B" {
			t.Fatalf("unexpected results ordering: %+v", results)
		}
		mu.Lock()
		defer mu.Unlock()
		if len(order) != 2 || order[0] != "A" || order[1] != "B" {
			t.Fatalf("expected order [A, B], got %v", order)
		}
	})
}

func TestPipeline_ErrorAndTimeout(t *testing.T) {
	ctx := context.Background()

	t.Run("stop on error skips dependent steps", func(t *testing.T) {
		var bRan atomic.Bool
		p := NewPipeline(
			Step{
				Name: "fail",
				Run: func(ctx context.Context) error {
					return fmt.Errorf("step failed")
				},
			},
			Step{
				Name:         "dependent",
				Dependencies: []string{"fail"},
				Run: func(ctx context.Context) error {
					bRan.Store(true)
					return nil
				},
			},
		)
		p.StopOnError = true
		results, err := p.Run(ctx)
		if err == nil {
			t.Fatal("expected error, got nil")
		}
		if bRan.Load() {
			t.Fatal("dependent step should not have run")
		}
		if len(results) != 2 || results[0].Success || results[1].Success {
			t.Fatalf("expected failure recorded: %+v", results)
		}
	})

	t.Run("step timeout", func(t *testing.T) {
		p := NewPipeline(
			Step{
				Name:    "hang",
				Timeout: 20 * time.Millisecond,
				Run: func(ctx context.Context) error {
					select {
					case <-time.After(100 * time.Millisecond):
						return nil
					case <-ctx.Done():
						return ctx.Err()
					}
				},
			},
		)
		results, err := p.Run(ctx)
		if err == nil || len(results) != 1 || results[0].Success {
			t.Fatalf("expected timeout error, got results=%+v err=%v", results, err)
		}
	})

	t.Run("global timeout", func(t *testing.T) {
		p := NewPipeline(
			Step{
				Name: "hang_global",
				Run: func(ctx context.Context) error {
					select {
					case <-time.After(200 * time.Millisecond):
						return nil
					case <-ctx.Done():
						return ctx.Err()
					}
				},
			},
		)
		p.GlobalTimeout = 30 * time.Millisecond
		results, err := p.Run(ctx)
		if err == nil || len(results) != 1 || results[0].Success {
			t.Fatalf("expected global timeout error, got results=%+v err=%v", results, err)
		}
	})
}

func TestPipeline_ValidationAndCallbacks(t *testing.T) {
	ctx := context.Background()

	t.Run("missing dependency validation error", func(t *testing.T) {
		p := NewPipeline(
			Step{Name: "orphan", Dependencies: []string{"nonexistent"}},
		)
		if _, err := p.Run(ctx); err == nil {
			t.Fatal("expected validation error for missing dependency")
		}
	})

	t.Run("cyclic dependency validation error", func(t *testing.T) {
		p := NewPipeline(
			Step{Name: "A", Dependencies: []string{"B"}},
			Step{Name: "B", Dependencies: []string{"A"}},
		)
		if _, err := p.Run(ctx); err == nil {
			t.Fatal("expected validation error for cyclic dependency")
		}
	})

	t.Run("duplicate step name error", func(t *testing.T) {
		p := NewPipeline(
			Step{Name: "dup"},
			Step{Name: "dup"},
		)
		if _, err := p.Run(ctx); err == nil {
			t.Fatal("expected validation error for duplicate step name")
		}
	})

	t.Run("callbacks invoked", func(t *testing.T) {
		var startCalls, completeCalls, logCalls int
		p := NewPipeline(
			Step{
				Name: "logged",
				Run:  func(ctx context.Context) error { return nil },
			},
		)
		p.OnStepStart = func(s Step) { startCalls++ }
		p.OnStepComplete = func(r StepResult) { completeCalls++ }
		p.OnStepLog = func(s, msg string) { logCalls++ }

		p.Log("logged", "test message")
		results, err := p.Run(ctx)
		if err != nil || len(results) != 1 || !results[0].Success {
			t.Fatalf("unexpected results: %+v err: %v", results, err)
		}
		if startCalls != 1 || completeCalls != 1 || logCalls != 1 {
			t.Fatalf("expected callback counts 1, got start=%d complete=%d log=%d", startCalls, completeCalls, logCalls)
		}
	})
}
