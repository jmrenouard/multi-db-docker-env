# Tutorial 1: Local Sandbox Setup

> **Learning Goal:** Verify host prerequisites, launch a standalone MySQL 8.4 sandbox behind Traefik v3, run SQL, and clean up.
>
> **Sandbox Scope:** Run this lab only in an isolated local Docker host.

## Prerequisites

- Docker Engine, Compose v2, and Go or prebuilt `bin/mdb`
- Free localhost ports `3306` and `8088`
- Terminal shell (`bash` or `PowerShell`, using `mdb.cmd` on Windows)

## Step 1: Check Host Readiness

Run the built-in diagnostic check:

```bash
./mdb doctor
```

Expected output:

```text
[OK]      docker     /usr/bin/docker
[OK]      compose    Docker Compose version v2...
[OK]      port 3306  available
```

## Step 2: Start Standalone `mysql84`

Launch MySQL 8.4 LTS with Traefik v3 routing:

```bash
./mdb up mysql84
```

Expected output:

```text
Environment mysql84 up successful
```

## Step 3: Open an Interactive SQL Client

Connect to the running container and verify the server version:

```bash
./mdb client mysql84
```

Inside the client prompt, execute:

```sql
SELECT VERSION();
```

Exit with `\q`.

## Step 4: Stop the Sandbox

Remove the standalone profile cleanly to free port `3306`:

```bash
./mdb down mysql84
```

Expected output:

```text
Stop completed successfully
```

## Next Steps

- Run production-style operations: [How-To Guides](../02-how-to-guides/index.md)
- Check all 31 environments and ports: [Reference](../03-reference/index.md)
- Understand Traefik single-port routing: [Explanation](../04-explanation/index.md)
