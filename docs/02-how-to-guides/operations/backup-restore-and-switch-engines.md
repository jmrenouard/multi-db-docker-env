# Back Up, Restore, and Switch Engines

Refer to the [MDB CLI and Makefile Reference](../../03-reference/cli-and-scripts/mdb-cli-and-makefile-reference.md) for backup and clean options.

## Preconditions

1. The target `galera` or `repli` cluster is active.
2. Backup directories (`gbackups_*` or `backups_*`) are writable on the host.
3. File `.env` holds the active `DB_ROOT_PASSWORD` value.

## Safety Precautions

**CAUTION:** Make a verified backup before you do physical restoration or clean commands. Physical restoration overwrites `/var/lib/mysql` on the target node.

## Procedure

1. Run a logical SQL dump for the target cluster:

```bash
./mdb backup <galera|repli>
```

2. Run a physical backup with MariaBackup if snapshot recovery is necessary:

```bash
./mdb backup <galera|repli> --physical
```

3. If you change standalone engines, stop the current profile first:

```bash
./mdb down <current-env> && ./mdb up <next-env>
```

4. If you restore a logical archive, run the restore command on the primary node:

```bash
./mdb restore <galera|repli> <backup.sql.gz>
```

5. If you restore a physical archive, run the physical restore command:

```bash
./mdb restore <galera|repli> <backup.tar.gz> --physical
```

**NOTE:** The `./mdb backup repli` command connects to `mariadb_02` to decrease primary node load.

## Verification Check

1. List archive files in the container `/backups` directory:

```bash
docker exec <container> ls -lh /backups
```

2. Connect with `./mdb client <env>` and examine the restored tables.
3. Run `./mdb test <env>` to make sure that cluster health is normal.

## Rollback Procedure

If logical or physical restoration causes data errors, stop the stack:

```bash
./mdb down <env>
```

Restore a previous verified archive or reset test data with `make clean-data`.

## Related Documentation

- Reference: [Topology and Port Matrix](../../03-reference/architecture-specs/topology-and-port-matrix.md)
- Explanation: [Architecture Overview](../../04-explanation/index.md)
