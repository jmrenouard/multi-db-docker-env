# PostgreSQL Support

PostgreSQL is now supported in the multi-db-docker-env project as a standalone database option.

## Supported Versions

- PostgreSQL 17
- PostgreSQL 16

## Quick Start

To start PostgreSQL 17:

```bash
make postgres17
```

To start PostgreSQL 16:

```bash
make postgres16
```

## Connection Details

The project uses Traefik to route traffic to the active PostgreSQL container.

| Setting | Value |
| :--- | :--- |
| Host | `127.0.0.1` |
| Port (Direct) | Docker assigned (see `docker ps`) |
| Port (Traefik) | `5432` |
| User | `postgres` |
| Password | `rootpass` (default, see `.env`) |

### Client Connection

You can use the `psql` client directly from your host if installed:

```bash
PGPASSWORD=rootpass psql -h 127.0.0.1 -p 5432 -U postgres
```

Or use the provided Makefile target:

```bash
make pgclient
```

## Management

- **Generate .pgpass**: `make pgpass` (saves credentials to `~/.pgpass` for automatic login)
- **Check Status**: `make status`
- **View Logs**: `make logs`
