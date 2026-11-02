package topology

type MongoTopology struct{ *BaseTopology }

func NewMongoTopology() *MongoTopology {
	return &MongoTopology{
		BaseTopology: NewBaseTopology(
			"mongo",
			"MongoDB 7 3-node ReplicaSet cluster with HAProxy",
			[]string{"docker-compose-mongo-rs.yml"},
			[]string{"ssl/mongo/ca.pem", "ssl/mongo/mongodb.pem"},
		),
	}
}

func NewMongo8Topology() *MongoTopology {
	return &MongoTopology{
		BaseTopology: NewBaseTopology(
			"mongo8",
			"MongoDB 8 3-node ReplicaSet cluster with HAProxy",
			[]string{"docker-compose-mongo8-rs.yml"},
			[]string{"ssl/certs/mongo8/ca.pem", "ssl/certs/mongo8/mongodb.pem"},
		),
	}
}
