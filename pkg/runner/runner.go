package runner

import (
	"context"
	"fmt"
	"sync"
	"time"
)

// Pipeline manages concurrent step execution respecting dependencies.
type Pipeline struct {
	Steps          []Step
	StopOnError    bool
	GlobalTimeout  time.Duration
	OnStepStart    func(step Step)
	OnStepComplete func(result StepResult)
	OnStepLog      func(step string, message string)

	mu      sync.Mutex
	results map[string]StepResult
}

// NewPipeline creates a new execution pipeline.
func NewPipeline(steps ...Step) *Pipeline {
	return &Pipeline{
		Steps:   steps,
		results: make(map[string]StepResult),
	}
}

// Validate checks for missing dependencies or cyclic relationships.
func (p *Pipeline) Validate() error {
	stepMap := make(map[string]Step)
	for _, s := range p.Steps {
		if _, exists := stepMap[s.Name]; exists {
			return fmt.Errorf("duplicate step name: %s", s.Name)
		}
		stepMap[s.Name] = s
	}

	for _, s := range p.Steps {
		for _, dep := range s.Dependencies {
			if _, exists := stepMap[dep]; !exists {
				return fmt.Errorf("step %s depends on missing step %s", s.Name, dep)
			}
		}
	}

	// Cycle detection using DFS
	visited := make(map[string]int) // 0: unvisited, 1: visiting, 2: visited
	var dfs func(name string) error
	dfs = func(name string) error {
		visited[name] = 1
		for _, dep := range stepMap[name].Dependencies {
			if visited[dep] == 1 {
				return fmt.Errorf("cyclic dependency detected involving step %s -> %s", name, dep)
			}
			if visited[dep] == 0 {
				if err := dfs(dep); err != nil {
					return err
				}
			}
		}
		visited[name] = 2
		return nil
	}

	for _, s := range p.Steps {
		if visited[s.Name] == 0 {
			if err := dfs(s.Name); err != nil {
				return err
			}
		}
	}
	return nil
}

// Log emits a log message through OnStepLog if configured.
func (p *Pipeline) Log(step, msg string) {
	if p.OnStepLog != nil {
		p.OnStepLog(step, msg)
	}
}

// Run executes the pipeline steps concurrently according to their dependencies.
func (p *Pipeline) Run(ctx context.Context) ([]StepResult, error) {
	if err := p.Validate(); err != nil {
		return nil, err
	}

	if p.GlobalTimeout > 0 {
		var cancel context.CancelFunc
		ctx, cancel = context.WithTimeout(ctx, p.GlobalTimeout)
		defer cancel()
	}

	p.mu.Lock()
	p.results = make(map[string]StepResult)
	p.mu.Unlock()

	completed := make(map[string]bool)
	started := make(map[string]bool)
	activeCount := 0
	var firstErr error

	var mu sync.Mutex
	cond := sync.NewCond(&mu)

	for {
		mu.Lock()
		if ctx.Err() != nil && firstErr == nil {
			firstErr = ctx.Err()
		}

		if (firstErr != nil && p.StopOnError) || ctx.Err() != nil {
			// Abort remaining unstarted steps
			for _, s := range p.Steps {
				if !started[s.Name] {
					res := StepResult{
						Name:    s.Name,
						Success: false,
						Error:   fmt.Errorf("cancelled: %w", firstErr),
					}
					p.mu.Lock()
					p.results[s.Name] = res
					p.mu.Unlock()
					completed[s.Name] = true
				}
			}
			for activeCount > 0 {
				cond.Wait()
			}
			mu.Unlock()
			break
		}

		if len(completed) >= len(p.Steps) {
			mu.Unlock()
			break
		}

		newlyStarted := 0
		for _, s := range p.Steps {
			if started[s.Name] {
				continue
			}

			// Check dependencies
			canRun := true
			for _, dep := range s.Dependencies {
				p.mu.Lock()
				depRes, done := p.results[dep]
				p.mu.Unlock()
				if !done || !depRes.Success {
					canRun = false
					break
				}
			}

			if canRun {
				started[s.Name] = true
				activeCount++
				newlyStarted++

				go func(step Step) {
					stepCtx := ctx
					var stepCancel context.CancelFunc
					if step.Timeout > 0 {
						stepCtx, stepCancel = context.WithTimeout(ctx, step.Timeout)
						defer stepCancel()
					}

					if p.OnStepStart != nil {
						p.OnStepStart(step)
					}

					start := time.Now()
					var runErr error
					if step.Run != nil {
						runErr = step.Run(stepCtx)
					}
					dur := time.Since(start)

					res := StepResult{
						Name:     step.Name,
						Success:  runErr == nil,
						Duration: dur,
						Error:    runErr,
					}

					p.mu.Lock()
					p.results[step.Name] = res
					p.mu.Unlock()

					if p.OnStepComplete != nil {
						p.OnStepComplete(res)
					}

					mu.Lock()
					completed[step.Name] = true
					activeCount--
					if runErr != nil && firstErr == nil {
						firstErr = runErr
					}
					cond.Broadcast()
					mu.Unlock()
				}(s)
			}
		}

		if newlyStarted == 0 {
			if activeCount == 0 {
				// No active steps and no new steps can start: unmet dependencies
				for _, s := range p.Steps {
					if !completed[s.Name] {
						p.mu.Lock()
						p.results[s.Name] = StepResult{
							Name:    s.Name,
							Success: false,
							Error:   fmt.Errorf("dependencies unfulfilled"),
						}
						p.mu.Unlock()
						completed[s.Name] = true
					}
				}
				mu.Unlock()
				break
			}
			cond.Wait()
		}
		mu.Unlock()
	}

	p.mu.Lock()
	defer p.mu.Unlock()
	ordered := make([]StepResult, len(p.Steps))
	for i, s := range p.Steps {
		ordered[i] = p.results[s.Name]
	}
	return ordered, firstErr
}
