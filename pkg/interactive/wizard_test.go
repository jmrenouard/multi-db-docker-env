package interactive

import (
	"bytes"
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/jmrenouard/multi-db-docker-env/pkg/catalog"
)

func TestRun_FrenchRetrySinglePromptAndHTMLEscaping(t *testing.T) {
	cat := catalog.NewCatalog(true)
	rpt := filepath.Join(t.TempDir(), "reports", "run_report.html")
	var out bytes.Buffer
	var ran [][]string

	// Input sequence (FR, direct env pg-streaming, interactive mode):
	// 1) "pg-streaming\n" -> select env
	// 2) "i\n"            -> mode interactive
	// 3) "o\n"            -> run config -> FAILS
	// 4) "c\n"            -> continue directly WITHOUT a second confirmation prompt
	// 5) "o\n"            -> run start -> SUCCEEDS (proves no duplicate prompt consumed 'o')
	// 6) "n\n"            -> skip status
	// 7) "o\n"            -> run verify -> SUCCEEDS via VerifyEnvironment
	in := strings.NewReader("pg-streaming\ni\no\nc\no\nn\no\n")
	err := Run(context.Background(), Options{
		Lang:       "fr",
		ReportPath: rpt,
		Catalog:    cat,
		In:         in,
		Out:        &out,
		Exec: func(_ context.Context, args []string) (string, string, error) {
			ran = append(ran, args)
			if args[0] == "config" {
				return "<script>alert(1)</script>", "<b>boom</b>", errors.New("config failed")
			}
			return "ok", "", nil
		},
		Verify: func(context.Context, catalog.Environment) (string, error) {
			return `{"status":"HEALTHY"}`, nil
		},
	})
	if err != nil {
		t.Fatalf("Run failed: %v\nout=%s", err, out.String())
	}
	output := out.String()
	if !strings.Contains(output, "[r]éessayer / [c]ontinuer / [s]top") {
		t.Fatalf("missing localized French retry prompt: %s", output)
	}
	if strings.Contains(output, "Continuer vers l'étape suivante") || strings.Contains(output, "Continue to next step") {
		t.Fatalf("unexpected duplicate continuation prompt in output: %s", output)
	}
	if len(ran) != 2 || ran[0][0] != "config" || ran[1][0] != "up" {
		t.Fatalf("unexpected executed steps (duplicate prompt check): %v", ran)
	}

	htmlBytes, err := os.ReadFile(rpt)
	if err != nil {
		t.Fatalf("read report: %v", err)
	}
	h := string(htmlBytes)
	if !strings.Contains(h, `data-finished="true"`) || strings.Contains(h, "<script>alert(1)</script>") || !strings.Contains(h, "&lt;script&gt;alert(1)&lt;/script&gt;") || !strings.Contains(h, "&lt;b&gt;boom&lt;/b&gt;") {
		t.Fatalf("report escaping/finished check failed:\n%s", h)
	}
}

func TestRun_AutoModeAndStopChoice(t *testing.T) {
	cat := catalog.NewCatalog(true)
	rpt := filepath.Join(t.TempDir(), "auto", "run_report.html")
	var out bytes.Buffer
	var ran [][]string
	err := Run(context.Background(), Options{
		Auto:       true,
		Lang:       "en",
		ReportPath: rpt,
		Catalog:    cat,
		In:         strings.NewReader(""),
		Out:        &out,
		Exec: func(_ context.Context, args []string) (string, string, error) {
			ran = append(ran, args)
			return "ok", "", nil
		},
		Verify: func(context.Context, catalog.Environment) (string, error) {
			return "HEALTHY", nil
		},
	})
	if err != nil {
		t.Fatalf("Auto Run failed: %v", err)
	}
	if len(ran) != 4 || ran[1][1] != "mariadb114" || ran[3][0] != "inject" {
		t.Fatalf("auto steps mismatch: %v", ran)
	}

	stopRpt := filepath.Join(t.TempDir(), "stop", "run_report.html")
	err = Run(context.Background(), Options{
		Interactive: true,
		Lang:        "en",
		ReportPath:  stopRpt,
		Catalog:     cat,
		In:          strings.NewReader("1\n1\ny\ns\n"),
		Out:         &out,
		Exec: func(context.Context, []string) (string, string, error) {
			return "", "err", errors.New("boom")
		},
		Verify: func(context.Context, catalog.Environment) (string, error) { return "", nil },
	})
	if err == nil || !strings.Contains(err.Error(), "aborted at step config") {
		t.Fatalf("expected abort error, got: %v", err)
	}
	b, _ := os.ReadFile(stopRpt)
	if !strings.Contains(string(b), `data-finished="true"`) {
		t.Fatalf("expected finished attribute on aborted report")
	}
}
