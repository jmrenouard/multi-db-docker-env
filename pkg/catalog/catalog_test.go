package catalog

import (
	"encoding/json"
	"os"
	"strings"
	"testing"
)

func TestCatalog_EntriesAndEOL(t *testing.T) {
	c := DefaultCatalog()
	if len(c.All()) != 36 || len(NewCatalog(false).All()) != 36 {
		t.Fatalf("counts: %d", len(c.All()))
	}
	if yt, ok := c.Lookup("yt-cluster"); !ok || yt.DefaultPort != 5491 {
		t.Fatalf("yt-cluster: %v %+v", ok, yt)
	}
	if pb, ok := c.Lookup("pg17-baseline"); !ok || pb.Container != "pg17_standalone" || pb.DefaultPort != 15431 || pb.ComposeFiles[0] != "docker-compose-pg17-baseline.yml" {
		t.Fatalf("pg17-baseline: %v %+v", ok, pb)
	}
	if len(c.Filter(CategoryStandalone, "", true, false)) != 11 || len(c.Filter(CategoryCluster, "", true, false)) != 20 || len(c.Filter("", "", false, true)) != 5 {
		t.Fatal("counts mismatch")
	}
	for _, id := range strings.Fields("mysql97 mysql84 mariadb123 mariadb118 mariadb114 mariadb1011 percona84 postgres18 postgres17 postgres16 postgres15") {
		if e, ok := c.Lookup(id); !ok || e.Profile != id || e.ComposeFiles[0] != "docker-compose.yml" || e.Container == "" || e.DefaultPort <= 0 {
			t.Fatalf("standalone %s", id)
		}
	}
	for _, id := range strings.Fields("galera repli innodb patroni pgpool mongo mongo8 pg17-baseline pg-streaming pg-logical pg-birep pg18-streaming pg18-logical pg18-birep pgedge bucardo citus cockroach yugabyte yt-cluster") {
		if e, ok := c.Lookup(id); !ok || len(e.ComposeFiles) == 0 || e.Container == "" || e.DefaultPort <= 0 {
			t.Fatalf("cluster %s", id)
		}
	}
	if crdb, _ := c.Lookup("cockroach"); !strings.Contains(crdb.Description, "v25.4") {
		t.Fatal(crdb.Description)
	}
	for id, exp := range map[string][2]string{
		"mysql57": {"2023-10-31", "mysql84, mysql97"}, "mysql80": {"2026-04-30", "mysql84, mysql97"},
		"mysql96": {"2026-04-21", "mysql97"}, "mariadb106": {"2026-07-06", "mariadb1011, mariadb114, mariadb118, mariadb123"},
		"percona80": {"2026-04-30", "percona84"},
	} {
		if e, ok := c.Lookup(id); !ok || e.Status != StatusEOL || e.EOLDate != exp[0] || e.Replacement != exp[1] {
			t.Fatalf("EOL %s: %+v", id, e)
		}
	}
}

func TestDefaultCatalog_FilterLookupRender(t *testing.T) {
	wd, _ := os.Getwd()
	defer func() { _ = os.Chdir(wd) }()
	_ = os.Chdir(t.TempDir())
	for _, id := range []string{"yt-cluster", "pg17-baseline"} {
		if _, ok := Lookup(id); !ok {
			t.Fatalf("%s must be unconditionally active", id)
		}
	}
	c := DefaultCatalog()
	for _, tc := range []struct {
		cat, eng string
		act, eol bool
		want     int
	}{
		{"", "postgresql", true, false, 17}, {CategoryStandalone, "pg", true, false, 4},
		{CategoryCluster, "mongo", true, false, 2}, {"", "mysql", true, true, 6}, {"", "", false, false, 0},
	} {
		if got := len(c.Filter(tc.cat, tc.eng, tc.act, tc.eol)); got != tc.want {
			t.Fatalf("%+v got %d", tc, got)
		}
	}
	if got := Filter(CategoryCluster, "cockroach", true, false); len(got) != 1 || got[0].ID != "cockroach" {
		t.Fatal(got)
	}
	e, ok := c.Lookup(" GALERA ")
	if !ok || e.ID != "galera" {
		t.Fatal(ok, e)
	}
	e.ComposeFiles[0] = "x.yml"
	if again, _ := c.Lookup("galera"); again.ComposeFiles[0] != "docker-compose-galera.yml" {
		t.Fatal("mutated")
	}
	if _, ok := Lookup("unknown"); ok {
		t.Fatal("expected false")
	}
	if out := RenderTable(c.Filter(CategoryStandalone, "percona", true, false)); !strings.Contains(out, "percona84") || strings.Contains(out, "REPLACEMENT") {
		t.Fatal(out)
	}
	if eol := RenderTable(c.Filter("", "", false, true)); !strings.Contains(eol, "REPLACEMENT") || !strings.Contains(eol, "2023-10-31") {
		t.Fatal(eol)
	}
	if !strings.Contains(RenderTable(nil), "No environments matched.") {
		t.Fatal("empty")
	}
	if js, err := RenderJSON(nil); err != nil || strings.TrimSpace(js) != "[]" {
		t.Fatal(js, err)
	}
	js, err := RenderJSON(c.Filter("", "yugabyte", true, false))
	var out []Environment
	if err != nil || json.Unmarshal([]byte(js), &out) != nil || len(out) != 1 || out[0].ID != "yugabyte" {
		t.Fatal(err, out)
	}
}
