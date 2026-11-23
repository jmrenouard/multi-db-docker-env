# Deploy Standalone Engines and Clusters

Refer to the [Topology and Port Matrix](../../03-reference/architecture-specs/topology-and-port-matrix.md) for ports and environment identifiers.

## Preconditions

1. Docker, Compose v2, and Bash are active on the host.
2. File `.env` exists with a custom `DB_ROOT_PASSWORD` value.
3. No active service uses port `3306` or `5432` on localhost.

## Safety Precautions

**CAUTION:** Stop active standalone containers before you start a different standalone profile. Port collisions on `3306` or `5432` cause startup failures.

## Procedure

1. Run the host diagnostic check:

```bash
./mdb doctor
```

2. List active environments in the catalog:

```bash
./mdb catalog --all
```

3. Start a standalone engine or cluster environment:

```bash
./mdb up <env>
```

4. If `<env>` uses a setup script, run the setup command:

```bash
./mdb setup <env>
```

5. If you deploy Galera, run the sequential bootstrap target:

```bash
make bootstrap-galera
```

**NOTE:** The `./mdb up` command generates missing TLS certificates automatically before container startup.

## Verification Check

1. Examine container state across active stacks:

```bash
./mdb status <env>
```

2. Run the native health check for a standalone engine or cluster:

```bash
./mdb test <env>
```

3. If `<env>` is a cluster with a test script, run the full suite:

```bash
./mdb test <env> --suite
```

4. Make sure that the output shows healthy node status and zero failed tests.

## Rollback Procedure

If deployment fails or a port conflict occurs, stop the environment:

```bash
./mdb down <env>
```

If containers stay active, stop all stacks:

```bash
./mdb down all
```

## Related Documentation

- Reference: [MDB CLI and Makefile Reference](../../03-reference/cli-and-scripts/mdb-cli-and-makefile-reference.md)
- Explanation: [Global Topology and Routing](../../04-explanation/architecture-overview/global-topology-and-routing.md)
