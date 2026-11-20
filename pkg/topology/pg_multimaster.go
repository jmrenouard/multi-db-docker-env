package topology

// PgStreamingTopology manages the 2-node PG 17 physical streaming replication stack.
type PgStreamingTopology struct{ *BaseTopology }

// NewPgStreamingTopology returns the pg-streaming topology definition.
func NewPgStreamingTopology() *PgStreamingTopology {
	return &PgStreamingTopology{
		BaseTopology: NewBaseTopology(
			"pg-streaming",
			"PostgreSQL 17 2-node physical streaming replication cluster (async/sync)",
			[]string{"docker-compose-pg-streaming.yml"},
			nil,
		),
	}
}

// PgLogicalTopology manages the 2-node PG 17 native uni-directional logical stack.
type PgLogicalTopology struct{ *BaseTopology }

// NewPgLogicalTopology returns the pg-logical topology definition.
func NewPgLogicalTopology() *PgLogicalTopology {
	return &PgLogicalTopology{
		BaseTopology: NewBaseTopology(
			"pg-logical",
			"PostgreSQL 17 2-node native uni-directional logical replication cluster",
			[]string{"docker-compose-pg-logical.yml"},
			nil,
		),
	}
}

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

// CockroachTopology manages the 3-node CockroachDB v25.4 Raft cluster.
type CockroachTopology struct{ *BaseTopology }

// NewCockroachTopology returns the cockroach topology definition.
func NewCockroachTopology() *CockroachTopology {
	return &CockroachTopology{
		BaseTopology: NewBaseTopology(
			"cockroach",
			"CockroachDB v25.4 3-node Raft RF=3 distributed SQL cluster",
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

// Pg18StreamingTopology manages the PG 18.6 physical streaming replication stack.
type Pg18StreamingTopology struct{ *BaseTopology }

// NewPg18StreamingTopology returns the pg18-streaming topology definition.
func NewPg18StreamingTopology() *Pg18StreamingTopology {
	return &Pg18StreamingTopology{
		BaseTopology: NewBaseTopology(
			"pg18-streaming",
			"PostgreSQL 18.6 standalone + 2-node physical streaming cluster (async/sync, AIO worker)",
			[]string{"docker-compose-pg18-streaming.yml"},
			nil,
		),
	}
}

// Pg18LogicalTopology manages the 2-node PG 18.6 uni-directional logical stack.
type Pg18LogicalTopology struct{ *BaseTopology }

// NewPg18LogicalTopology returns the pg18-logical topology definition.
func NewPg18LogicalTopology() *Pg18LogicalTopology {
	return &Pg18LogicalTopology{
		BaseTopology: NewBaseTopology(
			"pg18-logical",
			"PostgreSQL 18.6 2-node native uni-directional logical replication cluster",
			[]string{"docker-compose-pg18-logical.yml"},
			nil,
		),
	}
}

// Pg18BirepTopology manages the 2-node PG 18.6 bidirectional logical replication stack.
type Pg18BirepTopology struct{ *BaseTopology }

// NewPg18BirepTopology returns the pg18-birep topology definition.
func NewPg18BirepTopology() *Pg18BirepTopology {
	return &Pg18BirepTopology{
		BaseTopology: NewBaseTopology(
			"pg18-birep",
			"PostgreSQL 18.6 2-node bidirectional logical cluster (uuidv7 + HAProxy)",
			[]string{"docker-compose-pg18-birep.yml"},
			nil,
		),
	}
}

// YtClusterTopology manages the 3-node YT Cluster 1.21.3 (PG 18.7) active-active stack.
type YtClusterTopology struct{ *BaseTopology }

// NewYtClusterTopology returns the yt-cluster topology definition.
func NewYtClusterTopology() *YtClusterTopology {
	return &YtClusterTopology{
		BaseTopology: NewBaseTopology(
			"yt-cluster",
			"YT Cluster 1.21.3 (PostgreSQL 18.7) 3-node active-active cluster (yt_cluster + ytserv)",
			[]string{"docker-compose-yt-cluster.yml"},
			nil,
		),
	}
}

// Pg17BaselineTopology manages the PG 17 baseline standalone and sync primary/standby stack.
type Pg17BaselineTopology struct{ *BaseTopology }

// NewPg17BaselineTopology returns the pg17-baseline topology definition.
func NewPg17BaselineTopology() *Pg17BaselineTopology {
	return &Pg17BaselineTopology{
		BaseTopology: NewBaseTopology(
			"pg17-baseline",
			"PostgreSQL 17 baseline standalone and sync streaming primary/standby stack",
			[]string{"docker-compose-pg17-baseline.yml"},
			nil,
		),
	}
}
