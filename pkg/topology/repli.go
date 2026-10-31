package topology

type RepliTopology struct{ *BaseTopology }

func NewRepliTopology() *RepliTopology {
	return &RepliTopology{
		BaseTopology: NewBaseTopology(
			"repli",
			"MariaDB 3-node Primary-Replica GTID asynchronous replication cluster",
			[]string{"docker-compose-repli.yml"},
			[]string{"mariadb"},
		),
	}
}
