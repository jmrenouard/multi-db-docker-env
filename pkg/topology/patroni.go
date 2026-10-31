package topology

type PatroniTopology struct{ *BaseTopology }

func NewPatroniTopology() *PatroniTopology {
	return &PatroniTopology{
		BaseTopology: NewBaseTopology(
			"patroni",
			"PostgreSQL 17 Patroni High Availability cluster with etcd and HAProxy",
			[]string{"docker-compose-patroni.yml"},
			[]string{"patroni"},
		),
	}
}
