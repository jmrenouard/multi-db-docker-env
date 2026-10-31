package topology

type StandaloneTopology struct{ *BaseTopology }

func NewStandaloneTopology() *StandaloneTopology {
	return &StandaloneTopology{
		BaseTopology: NewBaseTopology(
			"standalone",
			"Standalone multi-version database profiles (MySQL, MariaDB, Percona, PostgreSQL, Traefik)",
			[]string{"docker-compose.yml"},
			[]string{"mariadb"},
		),
	}
}
