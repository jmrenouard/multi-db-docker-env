package topology

type PgPoolTopology struct{ *BaseTopology }

func NewPgPoolTopology() *PgPoolTopology {
	return &PgPoolTopology{
		BaseTopology: NewBaseTopology(
			"pgpool",
			"PostgreSQL 17 High Availability cluster with PgPool-II load balancer",
			[]string{"docker-compose-pgpool.yml"},
			[]string{"pgpool"},
		),
	}
}
