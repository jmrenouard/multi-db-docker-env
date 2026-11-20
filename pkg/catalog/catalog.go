// Package catalog provides a queryable registry of standalone, cluster, and EOL database environments.
package catalog

import (
	"bytes"
	"encoding/json"
	"fmt"
	"slices"
	"strings"
	"text/tabwriter"
)

// Category and lifecycle status values for Environment entries.
const (
	CategoryStandalone = "standalone"
	CategoryCluster    = "cluster"
	StatusActive       = "active"
	StatusEOL          = "eol"
)

// Environment describes a runnable or decommissioned database environment.
type Environment struct {
	ID            string   `json:"id"`
	Category      string   `json:"category"`
	Engine        string   `json:"engine"`
	Version       string   `json:"version"`
	Description   string   `json:"description"`
	ComposeFiles  []string `json:"compose_files,omitempty"`
	Profile       string   `json:"profile,omitempty"`
	Container     string   `json:"container,omitempty"`
	Status        string   `json:"status"`
	EOLDate       string   `json:"eol_date,omitempty"`
	Replacement   string   `json:"replacement,omitempty"`
	DefaultPort   int      `json:"default_port,omitempty"`
	SetupScript   string   `json:"setup_script,omitempty"`
	RequiredCerts []string `json:"required_certs,omitempty"`
}

// Catalog holds an ordered collection of database environments.
type Catalog struct{ envs []Environment }

var (
	stdYML  = []string{"docker-compose.yml"}
	mCerts  = []string{"ssl/ca-cert.pem", "ssl/server-cert.pem", "ssl/client-cert.pem"}
	iCerts  = []string{"ssl/innodb/ca-cert.pem", "ssl/innodb/server-cert.pem"}
	paCerts = []string{"certs_patroni/ca.crt", "certs_patroni/postgresql-server.crt"}
	ppCerts = []string{"ssl/pgpool/ca-cert.pem", "ssl/pgpool/server.crt"}
	mgCerts = []string{"ssl/mongo/ca.pem", "ssl/mongo/mongodb.pem"}
	mg8Cert = []string{"ssl/certs/mongo8/ca.pem", "ssl/certs/mongo8/mongodb.pem"}
	titles  = map[string]string{"mysql": "MySQL", "mariadb": "MariaDB", "percona": "Percona Server", "postgres": "PostgreSQL"}
	aliases = map[string]string{"postgresql": "postgres", "pg": "postgres", "mongo": "mongodb", "cockroach": "cockroachdb", "yugabyte": "yugabytedb", "percona-server": "percona"}
)

func sEnv(id, eng, ver string) Environment {
	ctr, desc, port := eng+"-"+ver, titles[eng]+" "+ver, 3306
	if eng == "percona" {
		ctr = "percona-server-" + ver
	}
	if eng == "postgres" {
		port = 5432
	} else {
		desc += " LTS"
	}
	return Environment{ID: id, Category: CategoryStandalone, Engine: eng, Version: ver, Description: desc + " standalone", ComposeFiles: stdYML, Profile: id, Container: ctr, Status: StatusActive, DefaultPort: port}
}

func cEnv(id, eng, ver, yml, ctr, setup, desc string, port int, certs []string) Environment {
	if yml == "" {
		yml = "docker-compose-" + id + ".yml"
	}
	if setup != "" && !strings.HasPrefix(setup, "conf/") {
		setup = "scripts/" + setup
	}
	return Environment{ID: id, Category: CategoryCluster, Engine: eng, Version: ver, Description: desc, ComposeFiles: []string{yml}, Container: ctr, Status: StatusActive, DefaultPort: port, SetupScript: setup, RequiredCerts: certs}
}

func pgC(id, ver, ctr, setup, desc string, port int, certs []string) Environment {
	return cEnv(id, "postgres", ver, "", ctr, setup, desc, port, certs)
}

func eEnv(id, eng, ver, eol, repl, desc string) Environment {
	return Environment{ID: id, Category: CategoryStandalone, Engine: eng, Version: ver, Description: desc, Status: StatusEOL, EOLDate: eol, Replacement: repl}
}

var baseEnvs = []Environment{
	sEnv("mysql97", "mysql", "9.7"),
	sEnv("mysql84", "mysql", "8.4"),
	sEnv("mariadb123", "mariadb", "12.3"),
	sEnv("mariadb118", "mariadb", "11.8"),
	sEnv("mariadb114", "mariadb", "11.4"),
	sEnv("mariadb1011", "mariadb", "10.11"),
	sEnv("percona84", "percona", "8.4"),
	sEnv("postgres18", "postgres", "18"),
	sEnv("postgres17", "postgres", "17"),
	sEnv("postgres16", "postgres", "16"),
	sEnv("postgres15", "postgres", "15"),

	cEnv("galera", "mariadb", "11.8", "", "galera_01", "", "MariaDB 3-node Galera cluster + HAProxy", 3306, mCerts),
	cEnv("repli", "mariadb", "11.8", "", "mariadb_02", "setup_repli.sh", "MariaDB 3-node GTID replication", 3406, mCerts),
	cEnv("innodb", "mysql", "8.4", "docker-compose-innodb-cluster.yml", "mysql_node1", "conf/innodb-cluster/setup_cluster.sh", "MySQL 8.4 InnoDB Cluster + HAProxy", 6446, iCerts),
	pgC("patroni", "17", "node1", "", "PG 17 Patroni HA + etcd + HAProxy", 5000, paCerts),
	pgC("pgpool", "17", "pgpool", "pgpool/setup_replication.sh", "PG 17 HA + PgPool-II", 9999, ppCerts),
	cEnv("mongo", "mongodb", "7.0", "docker-compose-mongo-rs.yml", "mongo1", "conf/mongo-rs/setup_rs.sh", "MongoDB 7 ReplicaSet + HAProxy", 27100, mgCerts),
	cEnv("mongo8", "mongodb", "8.0", "docker-compose-mongo8-rs.yml", "mongo8_n1", "conf/mongo-rs/setup_rs.sh", "MongoDB 8 ReplicaSet + HAProxy", 27200, mg8Cert),
	pgC("pg17-baseline", "17", "pg17_standalone", "", "PG 17 baseline standalone + sync standby", 15431, nil),
	pgC("pg-streaming", "17", "pg_stream_primary", "pg_streaming/setup_pg_streaming.sh", "PG 17 physical streaming", 15434, nil),
	pgC("pg-logical", "17", "pg_logical_pub", "pg_logical/setup_pg_logical.sh", "PG 17 uni-directional logical", 15436, nil),
	pgC("pg-birep", "17", "pg_birep_node1", "pg_birep/setup_birep.sh", "PG 17 bidirectional + HAProxy", 15440, nil),
	pgC("pg18-streaming", "18.6", "pg18_stream_primary", "pg18_streaming/setup_pg18_streaming.sh", "PG 18.6 physical streaming (AIO)", 15534, nil),
	pgC("pg18-logical", "18.6", "pg18_logical_pub", "pg18_logical/setup_pg18_logical.sh", "PG 18.6 uni-directional logical", 15536, nil),
	pgC("pg18-birep", "18.6", "pg18_birep_node1", "pg18_birep/setup_pg18_birep.sh", "PG 18.6 bidirectional (uuidv7)", 15540, nil),
	pgC("pgedge", "17", "pgedge_node1", "pgedge/setup_pgedge.sh", "PG 17 pgEdge Spock 5 mesh", 15450, nil),
	pgC("bucardo", "17", "bucardo_node1", "bucardo/setup_bucardo.sh", "PG 17 Bucardo 5 multi-master", 15461, nil),
	pgC("citus", "17", "citus_coord", "citus/setup_citus.sh", "Citus 14.2 distributed PG 17", 15490, nil),
	cEnv("cockroach", "cockroachdb", "25.4", "", "crdb_node1", "cockroach/setup_cockroach.sh", "CockroachDB v25.4 3-node Raft", 15481, nil),
	cEnv("yugabyte", "yugabytedb", "2026.1.3", "", "yb_node1", "yugabyte/setup_yugabyte.sh", "YugabyteDB 2026.1.3 3-node Raft", 15471, nil),
	pgC("yt-cluster", "18.7", "yt1", "yt_cluster/setup_yt_cluster.sh", "YT Cluster 1.21.3 (PG 18.7) active-active", 5491, nil),

	eEnv("mysql57", "mysql", "5.7", "2023-10-31", "mysql84, mysql97", "MySQL 5.7 (EOL)"),
	eEnv("mysql80", "mysql", "8.0", "2026-04-30", "mysql84, mysql97", "MySQL 8.0 (EOL)"),
	eEnv("mysql96", "mysql", "9.6", "2026-04-21", "mysql97", "MySQL 9.6 (EOL)"),
	eEnv("mariadb106", "mariadb", "10.6", "2026-07-06", "mariadb1011, mariadb114, mariadb118, mariadb123", "MariaDB 10.6 (EOL)"),
	eEnv("percona80", "percona", "8.0", "2026-04-30", "percona84", "Percona 8.0 (EOL)"),
}

// NewCatalog builds a Catalog with all standalone, cluster (including yt-cluster and pg17-baseline), and EOL environments.
func NewCatalog(_ bool) *Catalog {
	envs := make([]Environment, 0, len(baseEnvs))
	for _, e := range baseEnvs {
		envs = append(envs, cloneEnv(e))
	}
	return &Catalog{envs: envs}
}

// DefaultCatalog builds the full repository catalog unconditionally.
func DefaultCatalog() *Catalog { return NewCatalog(true) }

func cloneEnv(e Environment) Environment {
	e.ComposeFiles, e.RequiredCerts = slices.Clone(e.ComposeFiles), slices.Clone(e.RequiredCerts)
	return e
}

func normEngine(s string) string {
	k := strings.ToLower(strings.TrimSpace(s))
	if v, ok := aliases[k]; ok {
		return v
	}
	return k
}

// All returns defensive copies of all catalog entries.
func (c *Catalog) All() []Environment { return c.Filter("", "", true, true) }

// Filter returns entries matching optional category, engine, and status flags.
func (c *Catalog) Filter(category, engine string, includeActive, includeEOL bool) []Environment {
	cat, eng := strings.TrimSpace(category), normEngine(engine)
	out := make([]Environment, 0, len(c.envs))
	for _, e := range c.envs {
		if (cat != "" && !strings.EqualFold(e.Category, cat)) || (eng != "" && normEngine(e.Engine) != eng) ||
			(e.Status == StatusActive && !includeActive) || (e.Status == StatusEOL && !includeEOL) {
			continue
		}
		out = append(out, cloneEnv(e))
	}
	return out
}

// Lookup finds an environment by case-insensitive ID.
func (c *Catalog) Lookup(id string) (Environment, bool) {
	target := strings.ToLower(strings.TrimSpace(id))
	for _, e := range c.envs {
		if e.ID == target {
			return cloneEnv(e), true
		}
	}
	return Environment{}, false
}

// Filter queries DefaultCatalog() with optional category, engine, and status flags.
func Filter(category, engine string, includeActive, includeEOL bool) []Environment {
	return DefaultCatalog().Filter(category, engine, includeActive, includeEOL)
}

// Lookup finds an environment by ID in DefaultCatalog().
func Lookup(id string) (Environment, bool) { return DefaultCatalog().Lookup(id) }

func orDash(s string) string {
	if s == "" {
		return "-"
	}
	return s
}

// RenderTable formats environments as an aligned text table.
func RenderTable(envs []Environment) string {
	if len(envs) == 0 {
		return "No environments matched.\n"
	}
	eol := slices.ContainsFunc(envs, func(e Environment) bool { return e.Status == StatusEOL })
	var buf bytes.Buffer
	w := tabwriter.NewWriter(&buf, 0, 4, 2, ' ', 0)
	hdr := "ID\tCATEGORY\tENGINE\tVERSION\tSTATUS\tPORT\tDESCRIPTION"
	if eol {
		hdr = "ID\tCATEGORY\tENGINE\tVERSION\tSTATUS\tPORT\tEOL\tREPLACEMENT\tDESCRIPTION"
	}
	fmt.Fprintln(w, hdr)
	for _, e := range envs {
		port := "-"
		if e.DefaultPort > 0 {
			port = fmt.Sprintf("%d", e.DefaultPort)
		}
		row := []string{e.ID, e.Category, e.Engine, e.Version, e.Status, port}
		if eol {
			row = append(row, orDash(e.EOLDate), orDash(e.Replacement))
		}
		fmt.Fprintln(w, strings.Join(append(row, e.Description), "\t"))
	}
	_ = w.Flush()
	return buf.String()
}

// RenderJSON encodes environments as indented JSON, returning "[]" when empty.
func RenderJSON(envs []Environment) (string, error) {
	if envs == nil {
		envs = []Environment{}
	}
	b, err := json.MarshalIndent(envs, "", "  ")
	return string(b), err
}
