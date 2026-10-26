#!/usr/bin/env python3
"""Check TB371FC package manifests against Arch Linux ARM repository metadata."""

from __future__ import annotations

import argparse
import io
import json
import ssl
import sys
import tarfile
import urllib.request
from datetime import datetime, timezone
from pathlib import Path


DEFAULT_MIRROR = "https://ca.us.mirror.archlinuxarm.org"
DEFAULT_REPOSITORIES = ("core", "extra")


def read_manifest(path: Path) -> list[str]:
    packages: list[str] = []
    for line_number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if any(character.isspace() for character in line):
            raise ValueError(f"{path}:{line_number}: expected one package name")
        packages.append(line)
    return packages


def parse_desc(payload: bytes) -> dict[str, str]:
    lines = payload.decode("utf-8").splitlines()
    fields: dict[str, str] = {}
    index = 0
    while index < len(lines):
        marker = lines[index]
        if marker.startswith("%") and marker.endswith("%") and index + 1 < len(lines):
            fields[marker.strip("%")] = lines[index + 1]
            index += 2
        else:
            index += 1
    return fields


def fetch_repository(mirror: str, architecture: str, repository: str) -> dict[str, dict[str, str]]:
    url = f"{mirror.rstrip('/')}/{architecture}/{repository}/{repository}.db"
    request = urllib.request.Request(url, headers={"User-Agent": "tb371fc-port-manifest-check/1"})
    with urllib.request.urlopen(request, timeout=60, context=ssl.create_default_context()) as response:
        archive = response.read()

    packages: dict[str, dict[str, str]] = {}
    with tarfile.open(fileobj=io.BytesIO(archive), mode="r:*") as database:
        for member in database:
            if not member.isfile() or not member.name.endswith("/desc"):
                continue
            stream = database.extractfile(member)
            if stream is None:
                continue
            fields = parse_desc(stream.read())
            name = fields.get("NAME")
            version = fields.get("VERSION")
            if name and version:
                packages[name] = {
                    "repository": repository,
                    "version": version,
                }
    if not packages:
        raise RuntimeError(f"no package descriptions found in {url}")
    print(f"{repository}: {len(packages)} package records from {url}", file=sys.stderr)
    return packages


def main() -> int:
    project_root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "manifests",
        nargs="*",
        type=Path,
        default=sorted((project_root / "rootfs").glob("packages-*.txt")),
    )
    parser.add_argument("--mirror", default=DEFAULT_MIRROR)
    parser.add_argument("--architecture", default="aarch64")
    parser.add_argument("--write-lock", type=Path)
    args = parser.parse_args()

    manifests = [path.expanduser().resolve() for path in args.manifests]
    if not manifests:
        parser.error("no package manifests found")

    requested: dict[str, list[str]] = {}
    for manifest in manifests:
        if not manifest.is_file():
            parser.error(f"manifest does not exist: {manifest}")
        try:
            manifest_label = manifest.relative_to(project_root).as_posix()
        except ValueError:
            manifest_label = str(manifest)
        for package in read_manifest(manifest):
            requested.setdefault(package, []).append(manifest_label)

    available: dict[str, dict[str, str]] = {}
    for repository in DEFAULT_REPOSITORIES:
        available.update(fetch_repository(args.mirror, args.architecture, repository))

    missing = sorted(set(requested) - set(available))
    if missing:
        print("Manifest verification failed; packages not found:")
        for package in missing:
            print(f"  {package}")
        return 1

    lock = {
        "schema": 1,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "mirror": args.mirror,
        "architecture": args.architecture,
        "packages": {
            name: {
                **available[name],
                "manifests": requested[name],
            }
            for name in sorted(requested)
        },
    }
    if args.write_lock:
        lock_path = args.write_lock.expanduser().resolve()
        lock_path.parent.mkdir(parents=True, exist_ok=True)
        lock_path.write_text(json.dumps(lock, indent=2) + "\n", encoding="utf-8")
        print(f"Wrote resolved package lock: {lock_path}")

    print(f"Manifest verification passed: {len(requested)} packages are available")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
