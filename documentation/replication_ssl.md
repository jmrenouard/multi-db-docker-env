# Replication & SSL Configuration 🔐

Configure TLS encryption for MariaDB clusters and verify active ciphers. See [tls_setup.md](tls_setup.md) and [architecture.md](architecture.md).

## 🔑 Certificate Generation

The environment uses self-signed certificates for testing purposes.

1. **Script**: `make gen-ssl` (runs `gen_ssl.sh`)
2. **Process**:
   - Creates a Certificate Authority (CA).
   - Sign a Server certificate with the CA.
   - Sign a Client certificate with the CA.
3. **Files Created** (`ssl/` directory):
   - `ca-cert.pem`, `ca-key.pem`
   - `server-cert.pem`, `server-key.pem`
   - `client-cert.pem`, `client-key.pem`

## ⚙️ MariaDB SSL Configuration

All nodes use `ssl.cnf` to point to these certificates:

```ini
[mariadb]
ssl-ca=/etc/mysql/ssl/ca-cert.pem
ssl-cert=/etc/mysql/ssl/server-cert.pem
ssl-key=/etc/mysql/ssl/server-key.pem
```

> [!IMPORTANT]
> The `ssl/` directory is mounted as a volume in all containers at `/etc/mysql/ssl` with read-only permissions.

## 🔄 SSL in Replication

Run `setup_repli.sh` to encrypt data synchronization and the replication stream.

### Verification of SSL Status

Check the `Ssl_cipher` status variable to verify an encrypted connection:

```sql
SHOW STATUS LIKE 'Ssl_cipher';
```

The test suites (`test_repli.sh` and `test_galera.sh`) report the active SSL cipher for each node.

### Forcing SSL

Set `require_secure_transport=ON` in `ssl.cnf` to enforce SSL on all remote network connections.

## 🛡️ Diagram: SSL Architecture

```mermaid
graph LR
    subgraph "Host Workspace"
        CA["CA Key/Cert"] --> S_CSR["Server Key/Cert"]
        CA --> C_CSR["Client Key/Cert"]
    end
    
    subgraph "Docker Container"
        S_CSR --> M_CNF["ssl.cnf"]
        M_CNF --> Engine["MariaDB Engine"]
    end
    
    C_CSR --> App["Admin Tools / Client"]
    App -- "Encrypted Connection" --> Engine
```
