package config

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestConfig_DefaultAndValidate(t *testing.T) {
	cfg := DefaultConfig()
	if cfg.RootPassword == "" || cfg.Validate() != nil {
		t.Fatalf("invalid default config: %+v", cfg)
	}

	invalid := DefaultConfig()
	invalid.RootPassword = ""
	if invalid.Validate() == nil {
		t.Fatalf("expected error on empty password")
	}
}

func TestParseEnvReader(t *testing.T) {
	input := `
# comment
export SECRET="my-pass" # comment
NAME='cluster-node'
PORT=3306 # default
`
	res, err := ParseEnvReader(strings.NewReader(input))
	if err != nil || res["SECRET"] != "my-pass" || res["NAME"] != "cluster-node" || res["PORT"] != "3306" {
		t.Fatalf("unexpected parse result: %v, err: %v", res, err)
	}

	if _, err := ParseEnvReader(strings.NewReader("INVALID_LINE")); err == nil {
		t.Fatalf("expected syntax error on invalid line")
	}
}

func TestLoad_FileAndEnv(t *testing.T) {
	dir := t.TempDir()
	envPath := filepath.Join(dir, ".env")
	content := "DB_ROOT_PASSWORD=secret\nDEFAULT_SERVICE=pg16\nEXTRA_SANS=DNS:node1,IP:127.0.0.1\nOTHER=val"
	if err := os.WriteFile(envPath, []byte(content), 0600); err != nil {
		t.Fatal(err)
	}

	cfg, err := Load(envPath)
	if err != nil || cfg.RootPassword != "secret" || cfg.DefaultService != "pg16" || len(cfg.ExtraSANS) != 2 || cfg.CustomEnv["OTHER"] != "val" {
		t.Fatalf("unexpected loaded config: %+v, err: %v", cfg, err)
	}

	t.Setenv("DB_ROOT_PASSWORD", "override")
	if cfg2, _ := Load(envPath); cfg2.RootPassword != "override" {
		t.Fatalf("env override failed: %s", cfg2.RootPassword)
	}

	if _, err := Load(filepath.Join(dir, "missing.env")); err == nil {
		t.Fatalf("expected error for non-existent file")
	}
}
