# MDB CLI and Makefile Reference

CLI (`./mdb`, `mdb.cmd`) and [Makefile](../../../Makefile).

## `./mdb` Commands

| Command | Flags / Args | Purpose |
|---|---|---|
| `catalog` | `[--category standalone\|cluster] [--engine <e>] [--eol] [--all] [--json]` | List active or EOL envs. |
| `up` / `start` / `setup` | `<env>` (`mariadb114` default) | Ensure PKI, guard EOL, start/setup. |
| `down` / `stop` | `[env\|all]` | Stop target or all stacks. |
| `status` / `info` / `logs` | `[env\|svc] [--json] [--tail N] [-f]` | Show containers and logs. |
| `client` / `mycnf` / `interactive` | `[env]` / `[-a\|-i] [-l en\|fr]` | DB shell, `~/.my.cnf`, wizard. |
| `lint` / `doctor` / `config` | `[--env <path>]` | Check `.sh` + Compose, tools, `.env`. |
| `test <env>` | `[--suite]` | Health check (`--suite`: cluster `test_*.sh`). |
| `bench <env>` | `[--workload <w>] [--threads <n>] [--duration <d>]` | Run Sysbench, PG, or Mongo bench. |
| `pki` / `images` | `<generate\|verify> [topo] [--dir <d>]` / `<list\|build\|pull\|check>` | Manage PKI and 31 images. |
| `backup` / `restore` / `clean` | `<galera\|repli> [db\|file] [--physical]` / `<target>` | Dumps, MariaBackup, cleanup. |
| `inject` / `audit` / `report` | `<employees\|sakila>` / `<galera\|innodb\|repli\|all>` / `[--json\|--html]` | Seed DBs, MySQLTuner, reports. |

## `Makefile` Wrappers

- Targets: `make catalog`, `make status`, `make stop`, `make lint`, `make test-config`, `make bootstrap-galera`, `make emergency-galera`, `make gen-ssl-all`, `make check-ssl-all`, `make renew-ssl-galera`, `make renew-ssl-repli`, `make clean-data`.

## Exit Codes

| Code | Meaning |
|---|---|
| `0` | Success. |
| `1` | Runtime, EOL, Compose, or test error. |
| `2` | Invalid CLI flag (`flag.ExitOnError`). |
