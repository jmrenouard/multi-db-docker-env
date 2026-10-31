package topology

type GaleraTopology struct{ *BaseTopology }

func NewGaleraTopology() *GaleraTopology {
	return &GaleraTopology{
		BaseTopology: NewBaseTopology(
			"galera",
			"MariaDB 3-node Galera synchronous replication cluster with HAProxy",
			[]string{"docker-compose-galera.yml"},
			[]string{"mariadb"},
		),
	}
}
