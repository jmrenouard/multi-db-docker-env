# Configurer TLS, PKI et limites TDE

## Prérequis

- Vérifiez `openssl` dans le terminal ou sous WSL2.
- Lisez les modèles d'environnement sans exposer de secrets privés.

## Procédure

1. Générez les certificats locaux avec `./mdb pki generate` ou le Makefile.

```bash
./mdb pki generate all
make gen-ssl-all
```

2. Vérifiez l'expiration et la validité des chaînes de certificats.

```bash
./mdb pki verify all
make check-ssl-all
```

3. Renouvelez les certificats expirés pour Galera ou la réplication MySQL.

```bash
make renew-ssl-galera
make renew-ssl-repli
```

> [!CAUTION]
> Ne validez jamais de fichiers `.pem`, `.key`, `.crt` ou `.env` dans Git. Utilisez ces certificats uniquement pour les tests de laboratoire.

## Vérification

Exécutez `make check-ssl-all` et `./mdb doctor`. Vérifiez l'absence d'alerte TLS avant le redémarrage.

## Retour arrière

Exécutez `./mdb down all` et régénérez les certificats avec `make gen-ssl-all`. Consultez [les limites TDE](../../../documentation/tde_encryption_fr.md).
