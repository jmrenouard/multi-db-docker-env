package runner

import (
	"context"
	"time"
)

// Step represents an atomic execution unit in a runner pipeline.
type Step struct {
	Name         string
	Description  string
	Timeout      time.Duration
	Dependencies []string
	Run          func(ctx context.Context) error
}

// StepResult represents the execution outcome of a Step.
type StepResult struct {
	Name     string        `json:"name"`
	Success  bool          `json:"success"`
	Duration time.Duration `json:"duration"`
	Output   string        `json:"output,omitempty"`
	Error    error         `json:"error,omitempty"`
}
