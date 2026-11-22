package topology

import (
	"context"
	"fmt"
	"os"
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/jmrenouard/multi-db-docker-env/pkg/catalog"
	"github.com/jmrenouard/multi-db-docker-env/pkg/config"
	"github.com/jmrenouard/multi-db-docker-env/pkg/docker"
	"github.com/jmrenouard/multi-db-docker-env/pkg/pki"
)

var (
	defaultPollInterval = 2 * time.Second
	defaultReadyTimeout = 120 * time.Second
)

type Status struct {
	Topology string            `json:"topology"`
	Running  bool              `json:"running"`
	Services map[string]string `json:"services"`
}

type Topology interface {
	Name() string
	Description() string
	ComposeFiles() []string
	RequiredCerts() []string
	Up(ctx context.Context, client *docker.Client) error
	Down(ctx context.Context, client *docker.Client) error
	Status(ctx context.Context, client *docker.Client) (*Status, error)
	Verify(ctx context.Context, client *docker.Client) error
}

type BaseTopology struct {
	name          string
	description   string
	composeFiles  []string
	requiredCerts []string
}

var certFileChecks = map[string][]string{
	"mariadb": {"ssl/ca-cert.pem", "ssl/server-cert.pem", "ssl/client-cert.pem"},
	"innodb":  {"ssl/innodb/ca-cert.pem", "ssl/innodb/server-cert.pem"},
	"pgpool":  {"ssl/pgpool/ca-cert.pem", "ssl/pgpool/server.crt"},
	"patroni": {"certs_patroni/ca.crt", "certs_patroni/postgresql-server.crt"},
}

func NewBaseTopology(name, description string, composeFiles, requiredCerts []string) *BaseTopology {
	return &BaseTopology{
		name:          name,
		description:   description,
		composeFiles:  composeFiles,
		requiredCerts: requiredCerts,
	}
}

func (b *BaseTopology) Name() string            { return b.name }
func (b *BaseTopology) Description() string     { return b.description }
func (b *BaseTopology) ComposeFiles() []string  { return b.composeFiles }
func (b *BaseTopology) RequiredCerts() []string { return b.requiredCerts }

func (b *BaseTopology) Up(ctx context.Context, client *docker.Client) error {
	if err := b.EnsureCerts(ctx, client); err != nil {
		return err
	}
	if err := client.ComposeUp(ctx, b.composeFiles, defaultComposeEnv(), true); err != nil {
		return err
	}
	if err := b.waitBeforeSetup(ctx, client); err != nil {
		return err
	}
	if env, ok := catalog.DefaultCatalog().Lookup(b.name); ok && env.SetupScript != "" {
		args := append([]string{env.SetupScript}, env.SetupArgs...)
		if stdout, stderr, code, err := client.RunWithEnv(ctx, defaultScriptEnv(env.SetupEnv), "bash", args...); err != nil || code != 0 {
			msg := strings.TrimSpace(string(stderr))
			if msg == "" {
				msg = strings.TrimSpace(string(stdout))
			}
			return fmt.Errorf("topology %s setup %s failed (%d): %s: %w", b.name, env.SetupScript, code, msg, err)
		}
	}
	return b.waitAfterSetup(ctx, client)
}

func (b *BaseTopology) Down(ctx context.Context, client *docker.Client) error {
	return client.ComposeDown(ctx, b.composeFiles, true)
}

func (b *BaseTopology) Status(ctx context.Context, client *docker.Client) (*Status, error) {
	services, err := client.ComposePS(ctx, b.composeFiles)
	if err != nil {
		return nil, err
	}
	st := &Status{
		Topology: b.name,
		Running:  len(services) > 0,
		Services: make(map[string]string),
	}
	for _, s := range services {
		st.Services[s] = "running"
	}
	return st, nil
}

func (b *BaseTopology) Verify(ctx context.Context, client *docker.Client) error {
	st, err := b.Status(ctx, client)
	if err != nil {
		return err
	}
	if !st.Running {
		return fmt.Errorf("topology %s has no running services", b.name)
	}
	return nil
}

type Registry struct {
	mu         sync.RWMutex
	topologies map[string]Topology
}

func NewRegistry() *Registry {
	return &Registry{topologies: make(map[string]Topology)}
}

func (r *Registry) Register(t Topology) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.topologies[t.Name()] = t
}

func (r *Registry) Get(name string) (Topology, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	t, ok := r.topologies[name]
	if !ok {
		return nil, fmt.Errorf("unknown topology: %s", name)
	}
	return t, nil
}

func (r *Registry) List() []Topology {
	r.mu.RLock()
	defer r.mu.RUnlock()
	list := make([]Topology, 0, len(r.topologies))
	for _, t := range r.topologies {
		list = append(list, t)
	}
	sort.Slice(list, func(i, j int) bool {
		return list[i].Name() < list[j].Name()
	})
	return list
}

func DefaultRegistry() *Registry {
	r := NewRegistry()
	r.Register(NewStandaloneTopology())
	r.Register(NewGaleraTopology())
	r.Register(NewRepliTopology())
	r.Register(NewPatroniTopology())
	r.Register(NewPgPoolTopology())
	r.Register(NewInnoDBTopology())
	r.Register(NewMongoTopology())
	r.Register(NewMongo8Topology())
	r.Register(NewPgStreamingTopology())
	r.Register(NewPgLogicalTopology())
	r.Register(NewPgBirepTopology())
	r.Register(NewPg18StreamingTopology())
	r.Register(NewPg18LogicalTopology())
	r.Register(NewPg18BirepTopology())
	r.Register(NewPgEdgeTopology())
	r.Register(NewBucardoTopology())
	r.Register(NewCitusTopology())
	r.Register(NewCockroachTopology())
	r.Register(NewYugabyteTopology())
	r.Register(NewPg17BaselineTopology())
	r.Register(NewYtClusterTopology())
	return r
}

func filesExist(paths ...string) bool {
	for _, p := range paths {
		if _, err := os.Stat(p); err != nil {
			return false
		}
	}
	return true
}

func rootPassword() string {
	if cfg, err := config.Load(""); err == nil && cfg != nil {
		return cfg.RootPassword
	}
	return config.DefaultConfig().RootPassword
}

func defaultComposeEnv() map[string]string {
	if os.Getenv("DB_ROOT_PASSWORD") == "" && !filesExist(".env") {
		return map[string]string{"DB_ROOT_PASSWORD": rootPassword()}
	}
	return nil
}

func defaultScriptEnv(base []string) []string {
	env := append([]string(nil), base...)
	if os.Getenv("DB_ROOT_PASSWORD") == "" {
		env = append(env, "DB_ROOT_PASSWORD="+rootPassword())
	}
	return env
}

func waitUntil(ctx context.Context, timeout time.Duration, desc string, check func() (bool, error)) error {
	deadline := time.Now().Add(timeout)
	var lastErr error
	for {
		ok, err := check()
		if ok {
			return nil
		}
		if err != nil {
			lastErr = err
		}
		if time.Now().After(deadline) {
			if lastErr != nil {
				return fmt.Errorf("timeout waiting for %s: %w", desc, lastErr)
			}
			return fmt.Errorf("timeout waiting for %s", desc)
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(defaultPollInterval):
		}
	}
}

func waitNodes(ctx context.Context, desc string, nodes []string, probe func(string) (bool, error)) error {
	for _, n := range nodes {
		node := n
		if err := waitUntil(ctx, defaultReadyTimeout, node+" "+desc, func() (bool, error) { return probe(node) }); err != nil {
			return err
		}
	}
	return nil
}

// EnsureCerts generates missing TLS certificates required before container startup.
func (b *BaseTopology) EnsureCerts(ctx context.Context, client *docker.Client) error {
	if len(b.requiredCerts) == 0 {
		return nil
	}
	if b.name == "patroni" || b.requiredCerts[0] == "patroni" {
		if filesExist(certFileChecks["patroni"]...) {
			return nil
		}
		if _, se, code, err := client.RunWithEnv(ctx, []string{"CERT_DIR=certs_patroni"}, "bash", "scripts/patroni/generate_certs.sh"); err != nil || code != 0 {
			return fmt.Errorf("patroni cert generation failed (%d): %s: %w", code, strings.TrimSpace(string(se)), err)
		}
		return nil
	}
	paths, pkiTarget := b.requiredCerts, b.name
	if mapped, ok := certFileChecks[b.requiredCerts[0]]; ok {
		paths, pkiTarget = mapped, b.requiredCerts[0]
	}
	if filesExist(paths...) {
		return nil
	}
	return pki.NewPKIEngine("ssl").GenerateTopologyCerts(pkiTarget)
}

func (b *BaseTopology) waitBeforeSetup(ctx context.Context, client *docker.Client) error {
	sqlEnv := []string{"MYSQL_PWD=" + rootPassword()}
	sqlProbe := func(bin string) func(string) (bool, error) {
		return func(node string) (bool, error) {
			out, err := client.Exec(ctx, client.ResolveContainer(ctx, node), sqlEnv, bin, "-uroot", "-sN", "-e", "SELECT 1")
			return err == nil && strings.Contains(out, "1"), err
		}
	}
	mongoProbe := func(node string) (bool, error) {
		ping := []string{"mongosh", "--quiet", "--eval", "db.runCommand({ping:1})"}
		tlsArgs := append([]string{"mongosh", "--tls", "--tlsAllowInvalidCertificates", "--tlsCertificateKeyFile", "/etc/ssl/mongo/mongodb.pem"}, ping[1:]...)
		_, err := client.Exec(ctx, node, nil, tlsArgs...)
		if err != nil {
			_, err = client.Exec(ctx, node, nil, ping...)
		}
		return err == nil, err
	}
	switch b.name {
	case "repli":
		return waitNodes(ctx, "SQL", []string{"mariadb_01", "mariadb_02", "mariadb_03"}, sqlProbe("mariadb"))
	case "innodb":
		return waitNodes(ctx, "SQL", []string{"mysql_node1", "mysql_node2", "mysql_node3"}, sqlProbe("mysql"))
	case "pgpool":
		if err := waitNodes(ctx, "pg_isready", []string{"pg_node1", "pg_node2", "pg_node3"}, func(n string) (bool, error) {
			_, err := client.Exec(ctx, n, nil, "pg_isready", "-U", "postgres")
			return err == nil, err
		}); err != nil {
			return err
		}
		return waitUntil(ctx, defaultReadyTimeout, "pgpool", func() (bool, error) { return client.IsRunning(ctx, "pgpool") })
	case "mongo":
		return waitNodes(ctx, "mongod", []string{"mongo1", "mongo2", "mongo3"}, mongoProbe)
	case "mongo8":
		return waitNodes(ctx, "mongod", []string{"mongo8_n1", "mongo8_n2", "mongo8_n3"}, mongoProbe)
	default:
		return nil
	}
}

func (b *BaseTopology) waitAfterSetup(ctx context.Context, client *docker.Client) error {
	switch b.name {
	case "innodb", "mongo", "mongo8":
		ctr := "haproxy_" + b.name
		return waitUntil(ctx, defaultReadyTimeout, ctr, func() (bool, error) { return client.IsRunning(ctx, ctr) })
	case "pgpool":
		env := []string{"PGPASSWORD=" + rootPassword()}
		return waitUntil(ctx, defaultReadyTimeout, "pgpool backends", func() (bool, error) {
			out, err := client.Exec(ctx, "pgpool", env, "psql", "-h", "127.0.0.1", "-p", "9999", "-U", "postgres", "-c", "SHOW pool_nodes;")
			return err == nil && strings.Contains(out, "up"), err
		})
	default:
		return nil
	}
}
