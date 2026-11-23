# ADR-002: Diataxis and Versioned MkDocs Material Publishing

| Attribute | Value |
|---|---|
| **Status** | Accepted |
| **Deciders** | Multi-DB Engineering, LightPath Docs |

## Context

The repository holds 26 EN/FR files under `documentation/` plus root `README.md`, `README_fr.md`, and `Changelog`. Moving them breaks external links and `tests/test_docs_hygiene.py`, while single-branch docs omit immutable `v2.3.0+` releases.

## Options and Trade-Offs

| Option | Legacy Paths Intact | Versioned Tags | Verdict |
|---|---|---|---|
| Diataxis `docs/` + `mkdocs_hooks.py` + `build_versioned_docs.py` | Yes (`documentation/*.md` preserved) | Yes (`main` + `v2.3.0+`) | **Selected** |
| Move `documentation/*.md` into `docs/` | No (breaks links/tests) | Yes | Rejected |
| Static GitHub Wiki | Yes | No | Rejected |

## Decision

Keep `documentation/*.md` untouched and organize `docs/` into four Diataxis quadrants (`01-tutorials`..`04-explanation`). `scripts/mkdocs_hooks.py` injects `documentation/*.md`, `README*.md`, and `Changelog`, while `scripts/build_versioned_docs.py` builds immutable `v2.3.0+` overlays alongside `latest` (`main`) for IONOS SFTP hosting at `https://multi-db-docker-env.lightpath.fr/`.

## Consequences

- **Positive**: Strict genre separation, ASD-STE100 checks on `02-how-to-guides/`, and versioned static hosting.
- **Negative**: Links must resolve on disk (`test_docs_hygiene.py`) and through MkDocs hook rewrites.

## Related Reference and Procedures

- CLI reference: [MDB CLI and Makefile Reference](../../03-reference/cli-and-scripts/mdb-cli-and-makefile-reference.md)
- Deployment guide: [Deploy Standalone and Clusters](../../02-how-to-guides/deployment/deploy-standalone-and-clusters.md)
