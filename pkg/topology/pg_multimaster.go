package topology

// PgBirepTopology manages the 2-node PG 17 bidirectional logical replication stack.
type PgBirepTopology struct{ *BaseTopology }

// NewPgBirepTopology returns the pg-birep topology definition.
func NewPgBirepTopology() *PgBirepTopology {
	return &PgBirepTopology{
		BaseTopology: NewBaseTopology(
			"pg-birep",
			"PostgreSQL 17 2-node bidirectional logical replication cluster with HAProxy",
			[]string{"docker-compose-pg-birep.yml"},
			nil,
		),
	}
}

// PgEdgeTopology manages the 3-node pgEdge Spock 5 + Snowflake mesh.
type PgEdgeTopology struct{ *BaseTopology }

// NewPgEdgeTopology returns the pgedge topology definition.
func NewPgEdgeTopology() *PgEdgeTopology {
	return &PgEdgeTopology{
		BaseTopology: NewBaseTopology(
			"pgedge",
			"PostgreSQL 17 3-node pgEdge Spock 5 + Snowflake active-active mesh with HAProxy",
			[]string{"docker-compose-pgedge.yml"},
			nil,
		),
	}
}

// BucardoTopology manages the 2-node PG 17 + Bucardo 5 trigger multi-master stack.
type BucardoTopology struct{ *BaseTopology }

// NewBucardoTopology returns the bucardo topology definition.
func NewBucardoTopology() *BucardoTopology {
	return &BucardoTopology{
		BaseTopology: NewBaseTopology(
			"bucardo",
			"PostgreSQL 17 2-node Bucardo 5 trigger-based multi-master cluster",
			[]string{"docker-compose-bucardo.yml"},
			nil,
		),
	}
}

// CitusTopology manages the 3-node Citus 14.2 distributed PG 17 cluster.
type CitusTopology struct{ *BaseTopology }

// NewCitusTopology returns the citus topology definition.
func NewCitusTopology() *CitusTopology {
	return &CitusTopology{
		BaseTopology: NewBaseTopology(
			"citus",
			"Citus 14.2 distributed PostgreSQL 17 cluster (1 coordinator + 2 workers)",
			[]string{"docker-compose-citus.yml"},
			nil,
		),
	}
}

// CockroachTopology manages the 3-node CockroachDB v24.3.0 Raft cluster.
type CockroachTopology struct{ *BaseTopology }

// NewCockroachTopology returns the cockroach topology definition.
func NewCockroachTopology() *CockroachTopology {
	return &CockroachTopology{
		BaseTopology: NewBaseTopology(
			"cockroach",
			"CockroachDB v24.3.0 3-node Raft RF=3 distributed SQL cluster",
			[]string{"docker-compose-cockroach.yml"},
			nil,
		),
	}
}

// YugabyteTopology manages the 3-node YugabyteDB 2026.1.3 Raft cluster.
type YugabyteTopology struct{ *BaseTopology }

// NewYugabyteTopology returns the yugabyte topology definition.
func NewYugabyteTopology() *YugabyteTopology {
	return &YugabyteTopology{
		BaseTopology: NewBaseTopology(
			"yugabyte",
			"YugabyteDB 2026.1.3 3-node Raft RF=3 distributed YSQL cluster",
			[]string{"docker-compose-yugabyte.yml"},
			nil,
		),
	}
}
