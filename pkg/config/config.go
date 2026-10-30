package config

import (
	"bufio"
	"errors"
	"fmt"
	"io"
	"os"
	"strings"
)

type Config struct {
	RootPassword   string            `json:"root_password" yaml:"root_password"`
	DefaultService string            `json:"default_service" yaml:"default_service"`
	SSLDir         string            `json:"ssl_dir" yaml:"ssl_dir"`
	ReportsDir     string            `json:"reports_dir" yaml:"reports_dir"`
	TestDBDir      string            `json:"test_db_dir" yaml:"test_db_dir"`
	ExtraSANS      []string          `json:"extra_sans" yaml:"extra_sans"`
	CustomEnv      map[string]string `json:"custom_env" yaml:"custom_env"`
}

func DefaultConfig() *Config {
	return &Config{
		RootPassword:   "votre_mot_de_passe_super_secret",
		DefaultService: "mariadb118",
		SSLDir:         "ssl",
		ReportsDir:     "reports",
		TestDBDir:      "tests",
		ExtraSANS:      []string{},
		CustomEnv:      make(map[string]string),
	}
}

func ParseEnvReader(r io.Reader) (map[string]string, error) {
	env := make(map[string]string)
	scanner := bufio.NewScanner(r)
	for lineNum := 1; scanner.Scan(); lineNum++ {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		if strings.HasPrefix(line, "export ") {
			line = strings.TrimSpace(line[7:])
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			return nil, fmt.Errorf("line %d: invalid syntax (missing '=')", lineNum)
		}
		key, val := strings.TrimSpace(parts[0]), strings.TrimSpace(parts[1])
		if strings.HasPrefix(val, "\"") {
			if end := strings.LastIndex(val, "\""); end > 0 {
				val = val[1:end]
			}
		} else if strings.HasPrefix(val, "'") {
			if end := strings.LastIndex(val, "'"); end > 0 {
				val = val[1:end]
			}
		} else if idx := strings.Index(val, " #"); idx != -1 {
			val = strings.TrimSpace(val[:idx])
		}
		env[key] = val
	}
	return env, scanner.Err()
}

func Load(envPath string) (*Config, error) {
	cfg := DefaultConfig()
	target := envPath
	if target == "" {
		if _, err := os.Stat(".env"); err == nil {
			target = ".env"
		}
	}
	if target != "" {
		f, err := os.Open(target)
		if err != nil {
			return nil, fmt.Errorf("failed to open env file %s: %w", target, err)
		}
		defer f.Close()
		parsed, err := ParseEnvReader(f)
		if err != nil {
			return nil, fmt.Errorf("failed to parse %s: %w", target, err)
		}
		for k, v := range parsed {
			switch k {
			case "DB_ROOT_PASSWORD", "ROOT_PASSWORD":
				cfg.RootPassword = v
			case "DEFAULT_SERVICE", "DEFAULT_DB":
				cfg.DefaultService = v
			case "SSL_DIR":
				cfg.SSLDir = v
			case "REPORTS_DIR":
				cfg.ReportsDir = v
			case "TEST_DB_DIR":
				cfg.TestDBDir = v
			case "EXTRA_SANS":
				for _, p := range strings.Split(v, ",") {
					if t := strings.TrimSpace(p); t != "" {
						cfg.ExtraSANS = append(cfg.ExtraSANS, t)
					}
				}
			default:
				cfg.CustomEnv[k] = v
			}
		}
	}
	if envPass := os.Getenv("DB_ROOT_PASSWORD"); envPass != "" {
		cfg.RootPassword = envPass
	}
	if envSvc := os.Getenv("DEFAULT_SERVICE"); envSvc != "" {
		cfg.DefaultService = envSvc
	}
	if err := cfg.Validate(); err != nil {
		return nil, err
	}
	return cfg, nil
}

func (c *Config) Validate() error {
	if strings.TrimSpace(c.RootPassword) == "" ||
		strings.TrimSpace(c.DefaultService) == "" ||
		strings.TrimSpace(c.SSLDir) == "" ||
		strings.TrimSpace(c.ReportsDir) == "" ||
		strings.TrimSpace(c.TestDBDir) == "" {
		return errors.New("required config parameter is empty")
	}
	return nil
}
