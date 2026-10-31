package topology

import (
	"context"
	"fmt"
	"sort"
	"sync"

	"github.com/jmrenouard/multi-db-docker-env/pkg/docker"
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
	return client.ComposeUp(ctx, b.composeFiles, nil, true)
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
	return r
}
