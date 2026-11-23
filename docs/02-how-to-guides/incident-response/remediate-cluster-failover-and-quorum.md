# Remediate Cluster Failover and Quorum Loss

Refer to [Reference](../../03-reference/index.md) before you start cluster recovery.

## Preconditions

1. Docker daemon access is active on the host.
2. You found the failed topology (`galera`, `patroni`, `mongo`, `yugabyte`, or `cockroach`).
3. Client write traffic stays paused during recovery.

## Safety Precautions

**CAUTION:** Stop all Galera nodes before you bootstrap a single recovery node. Two simultaneous primary nodes cause split-brain data divergence.

## Procedure

1. Examine container state and recent logs for the target topology:

```bash
./mdb status <env> && ./mdb logs <env> --tail 100
```

2. If `galera` lost primary state after a full shutdown, bootstrap one node:

```bash
make emergency-galera NODE=1
```

3. If `patroni` lost its leader, examine the consensus state on a healthy node:

```bash
docker exec <healthy-node> patronictl -c /etc/patroni.yml list
```

4. If `mongo` or `mongo8` lost its primary, examine ReplicaSet member health:

```bash
./mdb status <mongo|mongo8>
```

5. If `yugabyte` or `cockroach` lost 2 of 3 nodes, restart the stopped containers to restore Raft quorum.

**NOTE:** Clusters with `RF=3` survive 1 node loss but stop writes on 2 node failures.

## Verification Check

1. Run the native topology verifier across all recovered clusters:

```bash
./mdb test <env>
```

2. Make sure that all cluster members report `running` and healthy state.
3. If `<env>` is `galera`, `patroni`, or `mongo`, run the failover script:

```bash
bash ./tests/test_failover.sh <galera|patroni|mongo>
```

4. For `mongo8`, `yugabyte`, and `cockroach`, examine `./mdb status <env>` output after recovery.

## Rollback Procedure

If emergency bootstrap or node restart fails, stop the stack:

```bash
./mdb down <env>
```

Start a clean topology with `./mdb up <env>` and restore the last verified backup.

## Related Documentation

- Reference: [Galera Bootstrap](../../../documentation/galera_bootstrap.md)
- Explanation: [Architecture Overview](../../04-explanation/index.md)
