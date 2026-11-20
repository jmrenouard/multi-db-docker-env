#!/usr/bin/env python3
"""Validate release version sync and extract Changelog release notes."""

from __future__ import annotations

import argparse
import pathlib
import re
import sys

SEMVER_RE = re.compile(r"^v?(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)$")
HEADER_RE = re.compile(r"^(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)\s+(\d{4}-\d{2}-\d{2})\s*$")
GO_VER_RE = re.compile(r'var\s+version\s*=\s*"([^"]+)"')


def resolve_tag(raw_tag: str, root: pathlib.Path) -> tuple[str, str, bool]:
    raw = raw_tag.strip() or (root / "VERSION").read_text(encoding="utf-8").strip()
    m = SEMVER_RE.match(raw)
    if not m:
        raise ValueError(f"Invalid semantic version/tag: {raw!r}")
    ver = m.group(1)
    return f"v{ver}", ver, "-" in ver


def extract_changelog_section(version: str, changelog: pathlib.Path) -> str:
    date, body = None, []
    for line in changelog.read_text(encoding="utf-8").splitlines():
        m = HEADER_RE.match(line)
        if m:
            if date is not None:
                break
            if m.group(1) == version:
                date = m.group(2)
            continue
        if date is not None:
            body.append(line)
    notes = "\n".join(body).strip()
    if date is None or not notes:
        raise ValueError(f"Missing or empty Changelog entry for {version!r}")
    return f"## Release v{version} ({date})\n\n{notes}\n"


def validate_version_sync(version: str, root: pathlib.Path) -> str:
    file_ver = (root / "VERSION").read_text(encoding="utf-8").strip()
    if file_ver != version:
        raise ValueError(f"Tag {version!r} != VERSION {file_ver!r}")
    go_match = GO_VER_RE.search((root / "cmd/mdb/main.go").read_text(encoding="utf-8"))
    if not go_match or go_match.group(1) != version:
        raise ValueError(f"cmd/mdb/main.go version mismatch for {version!r}")
    return extract_changelog_section(version, root / "Changelog")


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--tag", default="")
    p.add_argument("--root", type=pathlib.Path, default=pathlib.Path(__file__).resolve().parents[1])
    p.add_argument("--check", action="store_true")
    p.add_argument("--output", type=pathlib.Path)
    p.add_argument("--github-output", type=pathlib.Path)
    args = p.parse_args(argv)
    try:
        tag, ver, pre = resolve_tag(args.tag, args.root)
        notes = validate_version_sync(ver, args.root) if args.check else extract_changelog_section(ver, args.root / "Changelog")
    except (OSError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(notes, encoding="utf-8")
    elif not args.github_output:
        sys.stdout.write(notes)
    if args.github_output:
        with args.github_output.open("a", encoding="utf-8") as fh:
            fh.write(f"tag={tag}\nversion={ver}\nprerelease={'true' if pre else 'false'}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
