package interactive

import (
	"bufio"
	"bytes"
	"context"
	"strings"
	"testing"

	"github.com/jmrenouard/multi-db-docker-env/pkg/catalog"
	"github.com/jmrenouard/multi-db-docker-env/pkg/docker"
)

func TestParseArgsAndBuildSteps(t *testing.T) {
	opts, err := ParseArgs([]string{"-i", "--lang", "fr"})
	if err != nil || !opts.Interactive || opts.Lang != "fr" {
		t.Fatalf("ParseArgs fr: %+v err=%v", opts, err)
	}
	if _, err := ParseArgs([]string{"--lang", "de"}); err == nil {
		t.Fatalf("expected error on invalid lang")
	}

	cat := catalog.NewCatalog(true)
	pgEnv, _ := cat.Lookup("postgres18")
	pgSteps := BuildSteps(pgEnv, "en", func(context.Context, catalog.Environment) (string, error) { return "ok", nil })
	for _, st := range pgSteps {
		if st.ID == "inject" {
			t.Fatalf("postgres18 must skip MySQL-only inject step")
		}
		if st.ID == "verify" && strings.Contains(st.Command, "test-config") {
			t.Fatalf("verify step must use dbclient, not test-config: %s", st.Command)
		}
	}

	for _, id := range []string{"mongo8", "cockroach", "yugabyte"} {
		e, _ := cat.Lookup(id)
		for _, st := range BuildSteps(e, "fr", func(context.Context, catalog.Environment) (string, error) { return "ok", nil }) {
			if st.ID == "inject" {
				t.Fatalf("%s must skip inject step", id)
			}
		}
	}

	myEnv, _ := cat.Lookup("mysql97")
	hasInject := false
	for _, st := range BuildSteps(myEnv, "en", func(context.Context, catalog.Environment) (string, error) { return "ok", nil }) {
		if st.ID == "inject" && strings.Contains(st.Command, "sakila") {
			hasInject = true
		}
	}
	if !hasInject {
		t.Fatalf("mysql97 must include sakila inject step")
	}
}

func TestSelectEnvironmentFromFullCatalog(t *testing.T) {
	cat := catalog.NewCatalog(true)
	var out bytes.Buffer
	env, err := SelectEnvironment(bufio.NewReader(strings.NewReader("2\n1\n")), &out, cat, "en")
	if err != nil || env.Category != catalog.CategoryCluster || env.ID != "galera" {
		t.Fatalf("cluster pick: %+v err=%v", env, err)
	}
	// Direct environment ID entry works for any catalog item
	env2, err := SelectEnvironment(bufio.NewReader(strings.NewReader("pg-birep\n")), &out, cat, "fr")
	if err != nil || env2.ID != "pg-birep" {
		t.Fatalf("direct pick: %+v err=%v", env2, err)
	}
	// EOL ID rejected on both prompts
	if _, err := SelectEnvironment(bufio.NewReader(strings.NewReader("mysql80\n")), &out, cat, "en"); err == nil {
		t.Fatalf("expected EOL error for mysql80")
	}
	if _, err := SelectEnvironment(bufio.NewReader(strings.NewReader("1\nmysql57\n")), &out, cat, "en"); err == nil {
		t.Fatalf("expected EOL error on second prompt for mysql57")
	}
}

func TestVerifyEnvironment_WithMockDocker(t *testing.T) {
	mock := &docker.MockCommandRunner{
		Custom: func(_ context.Context, _ string, args ...string) ([]byte, []byte, int, error) {
			if len(args) > 0 && args[0] == "ps" {
				return []byte("postgres-18\n"), nil, 0, nil
			}
			return []byte("1\n"), nil, 0, nil
		},
	}
	env, _ := catalog.NewCatalog(false).Lookup("postgres18")
	out, err := VerifyEnvironment(context.Background(), env, docker.NewClientWithRunner(mock))
	if err != nil || !strings.Contains(out, "HEALTHY") {
		t.Fatalf("VerifyEnvironment err=%v out=%s", err, out)
	}
}
