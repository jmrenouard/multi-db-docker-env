# Configure TLS PKI and TDE Boundaries

Refer to [Reference](../../03-reference/index.md) and [TDE Guide](../../../documentation/tde_encryption.md) for encryption scope.

## Preconditions

1. OpenSSL or Go is available on the host.
2. Directories `ssl/` and `certs_patroni/` do not hold production keys in Git.
3. No expired certificate blocks active container mounts.

## Safety Precautions

**CAUTION:** Keep private keys at permission `0600` and do not commit keys to Git. Exposed keys compromise encrypted cluster traffic.

## Procedure

1. Generate X.509 certificates for all active topologies:

```bash
./mdb pki generate all
```

2. If you run Patroni, generate its mTLS bundle in `certs_patroni/`:

```bash
CERT_DIR=certs_patroni bash ./scripts/patroni/generate_certs.sh
```

3. Do a check of all CA chains and leaf certificates:

```bash
./mdb pki verify all && make check-ssl-all
```

4. Rotate TLS certificates with zero downtime on `galera` or `repli`:

```bash
make renew-ssl-galera   # or: make renew-ssl-repli
```

5. If storage TDE beyond host LUKS volumes is necessary, use MariaDB `file_key_management` or Percona `pg_tde`.

**NOTE:** Default Compose stacks activate local transport TLS only without an external KMS or storage TDE.

## Verification Check

1. Run the SSL security audit script:

```bash
bash ./tests/test_security_ssl.sh
```

2. Run `./mdb test <env>` on the active TLS cluster to make sure that TLS works.

## Rollback Procedure

If certificate rotation fails on `ssl/`, remove `ssl/` and generate new certificates:

```bash
rm -rf ssl/ && ./mdb pki generate all
```

If Patroni TLS fails, remove `certs_patroni/` and generate new Patroni certificates:

```bash
rm -rf certs_patroni/ && CERT_DIR=certs_patroni bash ./scripts/patroni/generate_certs.sh
```

Run `make renew-ssl-galera`, `make renew-ssl-repli`, or `./mdb down <env> && ./mdb up <env>`.

## Related Documentation

- Reference: [TLS Architecture](../../../documentation/tls_setup.md)
- Explanation: [Architecture Overview](../../04-explanation/index.md)
