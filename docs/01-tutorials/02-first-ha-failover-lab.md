# Tutorial 2: First HA Failover Lab

> **Learning Goal:** Deploy the 3-node PostgreSQL 17 Patroni cluster, verify leader election, run automated failover, and tear down.
>
> **Sandbox Scope:** Run this lab only in an isolated local Docker host.

## Prerequisites

- Completed [Tutorial 1](01-local-sandbox-setup.md)
- Minimum 4 GB free RAM for 7 containers (`etcd1`–`3`, `node1`–`3`, `haproxy-patroni`)
- Free localhost ports `5000`, `5001`, `7000`, and `2379`

## Step 1: Start Patroni HA

Auto-build images if absent, generate `certs_patroni/` mTLS PKI, and start the stack:

```bash
./mdb up patroni
```

Expected output:

```text
Environment patroni up successful
```

## Step 2: Inspect Leader and Replicas

Verify container status and inspect Patroni consensus state:

```bash
./mdb status patroni
docker exec node1 patronictl -c /etc/patroni.yml list
```

Expected output:

```text
| Member | Host  | Role    | State     | TL | Lag in MB |
| node1  | node1 | Leader  | running   |  1 |           |
| node2  | node2 | Replica | streaming |  1 |         0 |
| node3  | node3 | Replica | streaming |  1 |         0 |
```

## Step 3: Rehearse Automated Leader Failover

Stop the active leader and confirm a peer promotes automatically:

```bash
bash ./tests/test_failover.sh patroni
```

Expected output:

```text
✅ Patroni Failover: New Leader elected: node2
Passed: 1 | Failed: 0
```

## Step 4: Clean Up the Cluster

Stop all 7 containers and delete temporary lab volumes:

```bash
./mdb down patroni
```

## Next Steps

- Handle real split-brain and quorum recovery: [How-To Guides](../02-how-to-guides/index.md)
- Review HAProxy ports and error codes: [Reference](../03-reference/index.md)
- Understand quorum leases and TLS boundaries: [Explanation](../04-explanation/index.md)
