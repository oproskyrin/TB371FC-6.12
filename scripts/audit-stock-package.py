#!/usr/bin/env python3
"""Verify and summarize an extracted TB371FC QPST recovery package."""

from __future__ import annotations

import argparse
import hashlib
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


DEFAULT_RAWPROGRAMS = [
    "rawprogram0_save_persist1.xml",
    "rawprogram1.xml",
    "rawprogram2.xml",
    "rawprogram3.xml",
    "rawprogram4.xml",
    "rawprogram5.xml",
]

CRITICAL_FILES = [
    "boot.img",
    "recovery.img",
    "prog_firehose_ddr.elf",
    "rawprogram0_save_persist1.xml",
    "rawprogram4.xml",
    "abl.elf",
    "xbl.elf",
]


def digest(path: Path, algorithm: str) -> str:
    hasher = hashlib.new(algorithm)
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(8 * 1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def package_root(value: str) -> Path:
    root = Path(value).expanduser().resolve()
    if not (root / "image" / "MD5_DATA.xml").is_file():
        raise argparse.ArgumentTypeError(
            f"{root} does not contain image/MD5_DATA.xml"
        )
    return root


def verify_manifest(image_dir: Path) -> tuple[int, list[str]]:
    manifest_path = image_dir / "MD5_DATA.xml"
    manifest_text = manifest_path.read_bytes().decode("gb18030")
    manifest = ET.fromstring(manifest_text)
    entries = manifest.findall(".//FILE_ITEM")
    errors: list[str] = []

    for index, entry in enumerate(entries, 1):
        raw_name = entry.attrib.get("NAME", "")
        relative = raw_name.removeprefix(".\\").replace("\\", "/")
        path = image_dir / relative
        expected_md5 = (entry.findtext("MD5") or "").lower()
        expected_size_text = entry.findtext("SIZE") or ""

        if not path.is_file():
            errors.append(f"missing: {relative}")
            continue

        actual_size = path.stat().st_size
        try:
            expected_size = int(expected_size_text)
        except ValueError:
            errors.append(f"invalid manifest size for {relative}: {expected_size_text}")
            continue

        if actual_size != expected_size:
            errors.append(
                f"size mismatch: {relative}: expected {expected_size}, got {actual_size}"
            )
            continue

        actual_md5 = digest(path, "md5")
        if actual_md5 != expected_md5:
            errors.append(
                f"MD5 mismatch: {relative}: expected {expected_md5}, got {actual_md5}"
            )

        if index % 25 == 0 or index == len(entries):
            print(f"Manifest progress: {index}/{len(entries)}", file=sys.stderr)

    return len(entries), errors


def inspect_rawprograms(image_dir: Path) -> tuple[dict[str, list[str]], list[str]]:
    writes: dict[str, list[str]] = {}
    errors: list[str] = []

    for name in DEFAULT_RAWPROGRAMS:
        path = image_dir / name
        if not path.is_file():
            errors.append(f"missing default restore XML: {name}")
            continue

        labels: list[str] = []
        for program in ET.parse(path).findall(".//program"):
            filename = program.attrib.get("filename", "")
            label = program.attrib.get("label", "")
            if filename:
                labels.append(label or "<unlabelled>")
            if label == "persist" and filename:
                errors.append(f"{name} overwrites persist with {filename}")
        writes[name] = labels

    return writes, errors


def inspect_launcher(root: Path) -> list[str]:
    errors: list[str] = []
    launchers = list(root.glob("*.bat"))
    if len(launchers) != 1:
        return [f"expected one launcher BAT, found {len(launchers)}"]

    launcher = launchers[0].read_bytes().decode("gb18030", errors="replace")
    if "rawprogram0_save_persist1.xml" not in launcher:
        errors.append("launcher does not select the persist-preserving rawprogram")
    if "--setactivepartition=1" not in launcher:
        errors.append("launcher does not activate slot A after restore")
    if "FHLoaderErase.xml" not in launcher:
        errors.append("launcher does not run the expected erase preparation XML")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("package_root", type=package_root)
    args = parser.parse_args()

    root: Path = args.package_root
    image_dir = root / "image"

    count, manifest_errors = verify_manifest(image_dir)
    writes, rawprogram_errors = inspect_rawprograms(image_dir)
    launcher_errors = inspect_launcher(root)
    errors = manifest_errors + rawprogram_errors + launcher_errors

    print(f"Package: {root}")
    print(f"Manifest entries verified: {count - len(manifest_errors)}/{count}")
    print("Default restore write plan:")
    for name, labels in writes.items():
        print(f"  {name}: {', '.join(labels) if labels else '(no image writes)'}")

    print("Critical SHA-256:")
    for name in CRITICAL_FILES:
        path = image_dir / name
        if path.is_file():
            print(f"  {name}: {digest(path, 'sha256')}")
        else:
            errors.append(f"missing critical file: {name}")

    if errors:
        print("AUDIT FAILED:")
        for error in errors:
            print(f"  - {error}")
        return 1

    print("AUDIT PASSED: manifest, persist-preserving restore plan and launcher agree")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
