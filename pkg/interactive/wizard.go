package interactive

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"html"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/jmrenouard/multi-db-docker-env/pkg/catalog"
	"github.com/jmrenouard/multi-db-docker-env/pkg/docker"
)

// RenderHTML renders a live escaped HTML execution report.
func RenderHTML(title, installType, lang string, results []StepResult, finished bool) string {
	s := i18n[lang]
	passed, failed := 0, 0
	var body strings.Builder
	for i, res := range results {
		if res.Status == "SUCCESS" {
			passed++
		} else if res.Status == "FAILED" {
			failed++
		}
		outHTML := ""
		if res.Status != "PENDING" && res.Status != "SKIPPED" {
			so, se := s.NoOut, s.NoErr
			if res.Stdout != "" {
				so = html.EscapeString(res.Stdout)
			}
			if res.Stderr != "" {
				se = html.EscapeString(res.Stderr)
			}
			outHTML = fmt.Sprintf(`<div class="out"><div><h4>%s</h4><pre>%s</pre></div><div><h4>%s</h4><pre>%s</pre></div></div>`,
				html.EscapeString(s.Stdout), so, html.EscapeString(s.Stderr), se)
		}
		openAttr := ""
		if res.Status == "RUNNING" || res.Status == "FAILED" {
			openAttr = " open"
		}
		fmt.Fprintf(&body, `<section id="step-%s" class="step"><h3>%d. %s [%s]</h3><p>%s</p><details%s><summary>%s</summary><code>%s</code>%s</details></section>`,
			html.EscapeString(res.ID), i+1, html.EscapeString(res.Name), html.EscapeString(res.Status),
			html.EscapeString(res.Description), openAttr, html.EscapeString(s.Logs), html.EscapeString(res.Command), outHTML)
	}
	finAttr := ""
	if finished {
		finAttr = ` data-finished="true"`
	}
	return fmt.Sprintf(`<!DOCTYPE html><html lang="%s"><head><meta charset="UTF-8"><title>%s</title><style>body{font-family:system-ui,sans-serif;background:#0f172a;color:#f1f5f9;padding:2rem}.step{background:#1e293b;border-radius:8px;padding:1rem;margin:.75rem 0}pre,code{background:#020617;padding:.5rem;display:block;overflow-x:auto}.out{display:grid;grid-template-columns:1fr 1fr;gap:1rem}</style></head><body%s><h1>%s</h1><p>%s | Steps: %d | Passed: %d | Failed: %d</p>%s</body></html>`,
		html.EscapeString(lang), html.EscapeString(title), finAttr, html.EscapeString(title),
		html.EscapeString(installType), len(results), passed, failed, body.String())
}

func writeReport(path, title, installType, lang string, results []StepResult, finished bool) error {
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		return err
	}
	return os.WriteFile(path, []byte(RenderHTML(title, installType, lang, results, finished)), 0644)
}

func defaultExecutor(ctx context.Context, args []string) (string, string, error) {
	exe, err := os.Executable()
	if err != nil {
		exe = "go"
		args = append([]string{"run", "./cmd/mdb"}, args...)
	}
	cmd := exec.CommandContext(ctx, exe, args...)
	var outBuf, errBuf strings.Builder
	cmd.Stdout, cmd.Stderr = &outBuf, &errBuf
	err = cmd.Run()
	return outBuf.String(), errBuf.String(), err
}

// Run executes the interactive or automated wizard pipeline.
func Run(ctx context.Context, opts Options) error {
	if opts.Catalog == nil {
		opts.Catalog = catalog.DefaultCatalog()
	}
	if opts.In == nil {
		opts.In = os.Stdin
	}
	if opts.Out == nil {
		opts.Out = os.Stdout
	}
	if opts.ReportPath == "" {
		opts.ReportPath = filepath.Join("reports", "run_report.html")
	}
	if opts.Exec == nil {
		opts.Exec = defaultExecutor
	}
	if opts.Verify == nil {
		dc := opts.DockerClient
		if dc == nil {
			dc = docker.NewClient()
		}
		opts.Verify = func(c context.Context, e catalog.Environment) (string, error) {
			return VerifyEnvironment(c, e, dc)
		}
	}

	r := bufio.NewReader(opts.In)
	lang := opts.Lang
	if lang == "" {
		lang = "en"
		if !opts.Auto {
			fmt.Fprint(opts.Out, i18n["en"].LangPrompt)
			if ans := strings.ToLower(readLine(r)); ans == "f" || ans == "fr" {
				lang = "fr"
			}
		}
	}
	s := i18n[lang]

	var env catalog.Environment
	if opts.Auto {
		var ok bool
		if env, ok = opts.Catalog.Lookup("mariadb114"); !ok {
			act := opts.Catalog.Filter(catalog.CategoryStandalone, "", true, false)
			if len(act) == 0 {
				return errors.New("no active environment found")
			}
			env = act[0]
		}
	} else {
		var err error
		if env, err = SelectEnvironment(r, opts.Out, opts.Catalog, lang); err != nil {
			return err
		}
	}

	interactiveMode := opts.Interactive
	if !opts.Auto && !opts.Interactive {
		fmt.Fprint(opts.Out, s.ModePrompt)
		interactiveMode = strings.ToLower(readLine(r)) != "a"
	}
	if interactiveMode {
		fmt.Fprintln(opts.Out, s.InterLabel)
	} else {
		fmt.Fprintln(opts.Out, s.AutoLabel)
	}

	steps := BuildSteps(env, lang, opts.Verify)
	results := make([]StepResult, len(steps))
	for i, st := range steps {
		results[i] = StepResult{Step: st, Status: "PENDING"}
	}
	installType := fmt.Sprintf("%s (%s)", env.Category, env.ID)
	_ = writeReport(opts.ReportPath, s.Dashboard, installType, lang, results, false)

	for i, st := range steps {
		fmt.Fprintf(opts.Out, "\n[%d/%d] %s - %s\n", i+1, len(steps), st.Name, st.Description)
		for {
			if interactiveMode {
				fmt.Fprint(opts.Out, s.RunStep)
				if strings.ToLower(readLine(r)) == "n" {
					results[i].Status = "SKIPPED"
					_ = writeReport(opts.ReportPath, s.Dashboard, installType, lang, results, false)
					break
				}
			}
			results[i].Status = "RUNNING"
			_ = writeReport(opts.ReportPath, s.Dashboard, installType, lang, results, false)
			fmt.Fprintf(opts.Out, s.Executing+"\n", st.Command)

			var so, se string
			var err error
			if st.Run != nil {
				so, se, err = st.Run(ctx)
			} else {
				so, se, err = opts.Exec(ctx, st.Args)
			}
			results[i].Stdout, results[i].Stderr = so, se
			if err == nil {
				results[i].Status = "SUCCESS"
				_ = writeReport(opts.ReportPath, s.Dashboard, installType, lang, results, false)
				break
			}
			results[i].Status = "FAILED"
			_ = writeReport(opts.ReportPath, s.Dashboard, installType, lang, results, false)
			fmt.Fprintf(opts.Out, s.Failed+"\n", err)
			if !interactiveMode {
				_ = writeReport(opts.ReportPath, s.Dashboard, installType, lang, results, true)
				return err
			}
			fmt.Fprint(opts.Out, s.RetryPrompt)
			choice := strings.ToLower(readLine(r))
			if choice == "" || choice == "r" {
				continue
			}
			if choice == "s" {
				_ = writeReport(opts.ReportPath, s.Dashboard, installType, lang, results, true)
				return fmt.Errorf("aborted at step %s (%s): %w", st.ID, time.Now().Format(time.Kitchen), err)
			}
			break // 'c' continues directly to the next step without a duplicate prompt
		}
	}
	if err := writeReport(opts.ReportPath, s.Dashboard, installType, lang, results, true); err != nil {
		return err
	}
	fmt.Fprintf(opts.Out, s.FinalReport, opts.ReportPath)
	return nil
}
