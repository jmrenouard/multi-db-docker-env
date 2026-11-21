package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"

	"github.com/jmrenouard/multi-db-docker-env/pkg/docker"
)

func TestImagesCmd(t *testing.T) {
	ctx, tags := context.Background(), make([]string, 0, len(e2eImages))
	for _, s := range e2eImages {
		tags = append(tags, s.Image)
	}
	var out bytes.Buffer
	partial := docker.NewClientWithRunner(&docker.MockCommandRunner{Output: []byte("mariadb_ssh:004\npostgres:17\nalpine:latest\n")})
	if err := runImagesCmd(ctx, partial, []string{"list"}, &out); err != nil || !strings.Contains(out.String(), "PRESENT") || !strings.Contains(out.String(), "MISSING") {
		t.Fatalf("list: %v %s", err, out.String())
	}
	out.Reset()
	var parsed []imageStatus
	if err := runImagesCmd(ctx, partial, []string{"list", "--json"}, &out); err != nil || json.Unmarshal(out.Bytes(), &parsed) != nil || len(parsed) != len(e2eImages) {
		t.Fatalf("list --json: %v len=%d", err, len(parsed))
	}
	out.Reset()
	if err := runImagesCmd(ctx, partial, []string{"check"}, &out); err == nil || !strings.Contains(out.String(), "patroni-rhel8-etcd:latest") {
		t.Fatalf("check missing: %v %s", err, out.String())
	}
	full := docker.NewClientWithRunner(&docker.MockCommandRunner{Output: []byte(strings.Join(tags, "\n") + "\n")})
	out.Reset()
	if err := runImagesCmd(ctx, full, []string{"check"}, &out); err != nil || !strings.Contains(out.String(), "OK: all") {
		t.Fatalf("check ok: %v %s", err, out.String())
	}
	mock := &docker.MockCommandRunner{}
	cli := docker.NewClientWithRunner(mock)
	for _, tc := range []struct {
		args []string
		n    int
		want string
	}{
		{[]string{"build"}, 7, "scripts/Dockerfile.bench"}, {[]string{"build", "mariadb"}, 1, "mariadb_ssh:004"},
		{[]string{"build", "bucardo"}, 2, "Dockerfile.pg"}, {[]string{"build", "patroni"}, 3, "Dockerfile.postgresql"},
		{[]string{"build", "bench"}, 1, "pgbench-sysbench"}, {[]string{"pull"}, 24, "traefik:v3"},
		{[]string{"pull", "standalone"}, 12, "postgres:18"}, {[]string{"pull", "clusters"}, 10, "dbinvent/yt:1.21.3"},
		{[]string{"pull", "helpers"}, 2, "postgres:17-alpine"},
	} {
		mock.Calls, out = nil, bytes.Buffer{}
		if err := runImagesCmd(ctx, cli, tc.args, &out); err != nil || len(mock.Calls) != tc.n || !strings.Contains(out.String(), tc.want) {
			t.Fatalf("%v: err=%v calls=%d", tc.args, err, len(mock.Calls))
		}
	}
	fail := docker.NewClientWithRunner(&docker.MockCommandRunner{ExitCode: 1, Err: errors.New("boom"), Stderr: []byte("err")})
	for _, bad := range [][]string{nil, {"bogus"}, {"build", "bad"}, {"pull", "bad"}} {
		if runImagesCmd(ctx, cli, bad, &out) == nil {
			t.Fatalf("want err for %v", bad)
		}
	}
	for _, act := range [][]string{{"list"}, {"check"}, {"build", "bench"}, {"pull", "helpers"}} {
		if runImagesCmd(ctx, fail, act, &out) == nil {
			t.Fatalf("want daemon err for %v", act)
		}
	}
}

func TestImagesInventory_CoversAllComposeFiles(t *testing.T) {
	known := make(map[string]bool, len(e2eImages))
	for _, s := range e2eImages {
		if known[s.Image] {
			t.Fatalf("duplicate: %s", s.Image)
		}
		known[s.Image] = true
	}
	files, err := filepath.Glob(filepath.Join("..", "..", "docker-compose*.yml"))
	if err != nil || len(files) < 20 {
		t.Fatalf("compose count=%d err=%v", len(files), err)
	}
	re := regexp.MustCompile(`(?m)^\s*image:\s*['"]?([^\s'"#]+)['"]?`)
	for _, f := range files {
		data, err := os.ReadFile(f)
		if err != nil {
			t.Fatal(err)
		}
		for _, m := range re.FindAllStringSubmatch(string(data), -1) {
			if !known[m[1]] {
				t.Errorf("%s image %q missing from e2eImages", filepath.Base(f), m[1])
			}
		}
	}
}
