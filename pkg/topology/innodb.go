package topology

type InnoDBTopology struct{ *BaseTopology }

func NewInnoDBTopology() *InnoDBTopology {
	return &InnoDBTopology{
		BaseTopology: NewBaseTopology(
			"innodb",
			"MySQL 8.4 InnoDB Cluster with Group Replication and MySQL Router",
			[]string{"docker-compose-innodb-cluster.yml"},
			[]string{"innodb"},
		),
	}
}
