#!/usr/bin/env python3
"""Generate a read-only Firehose XML for critical TB371FC partitions."""

from __future__ import annotations

import argparse
import json
import xml.etree.ElementTree as ET
from pathlib import Path


RAWPROGRAMS = [f"rawprogram{lun}.xml" for lun in range(6)]

REQUIRED_LABELS = {
    "ssd",
    "persist",
    "misc",
    "keystore",
    "frp",
    "metadata",
    "vm-system_a",
    "vm-system_b",
    "modemst1",
    "modemst2",
    "fsg",
    "fsc",
    "boot_b",
    "recovery_b",
    "dtbo_b",
    "vbmeta_b",
    "vbmeta_system_b",
    "multiimgoem_a",
    "multiimgoem_b",
    "multiimgqti_a",
    "multiimgqti_b",
    "vm-linux_a",
    "vm-linux_b",
    "devinfo",
    "dip",
    "apdp",
    "msadp",
    "storsec",
    "uefivarstore",
    "secdata",
    "vm-keystore",
    "vm-data",
}


def package_root(value: str) -> Path:
    root = Path(value).expanduser().resolve()
    if not (root / "image" / "rawprogram0.xml").is_file():
        raise argparse.ArgumentTypeError(f"{root} is not an extracted QPST package")
    return root


def collect_partitions(image_dir: Path) -> tuple[list[dict[str, str]], list[str]]:
    selected: list[dict[str, str]] = []
    found: set[str] = set()

    for rawprogram in RAWPROGRAMS:
        path = image_dir / rawprogram
        if not path.is_file():
            raise FileNotFoundError(path)
        for program in ET.parse(path).findall(".//program"):
            label = program.attrib.get("label", "")
            if label not in REQUIRED_LABELS:
                continue
            if label in found:
                raise ValueError(f"duplicate partition label in stock XML: {label}")
            found.add(label)
            selected.append(dict(program.attrib))

    missing = sorted(REQUIRED_LABELS - found)
    return selected, missing


def add_gpt_reads(image_dir: Path, selected: list[dict[str, str]]) -> None:
    for lun, rawprogram in enumerate(RAWPROGRAMS):
        path = image_dir / rawprogram
        programs = ET.parse(path).findall(".//program")
        for label in ("PrimaryGPT", "BackupGPT"):
            matches = [entry for entry in programs if entry.attrib.get("label") == label]
            if len(matches) != 1:
                raise ValueError(f"{rawprogram}: expected one {label}, found {len(matches)}")
            attributes = dict(matches[0].attrib)
            attributes["label"] = f"{label}_lun{lun}"
            selected.append(attributes)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("package_root", type=package_root)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()

    image_dir = args.package_root / "image"
    output_dir = args.output_dir.expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    selected, missing = collect_partitions(image_dir)
    if missing:
        raise SystemExit(f"stock XML is missing required labels: {', '.join(missing)}")
    add_gpt_reads(image_dir, selected)

    root = ET.Element("data")
    root.append(ET.Comment("READ-ONLY TB371FC backup; generated from stock GPT XML"))
    inventory: list[dict[str, object]] = []

    for partition in sorted(
        selected,
        key=lambda item: (
            int(item["physical_partition_number"]),
            item.get("start_sector", ""),
        ),
    ):
        label = partition["label"]
        lun = int(partition["physical_partition_number"])
        filename = f"lun{lun}-{label}.bin"
        sector_size = int(partition["SECTOR_SIZE_IN_BYTES"])
        sector_count = int(partition["num_partition_sectors"])

        read = ET.SubElement(root, "read")
        for key in (
            "SECTOR_SIZE_IN_BYTES",
            "num_partition_sectors",
            "physical_partition_number",
            "start_sector",
        ):
            read.set(key, partition[key])
        read.set("file_sector_offset", "0")
        read.set("filename", filename)

        inventory.append(
            {
                "label": label,
                "lun": lun,
                "start_sector": partition["start_sector"],
                "sector_count": sector_count,
                "sector_size": sector_size,
                "expected_bytes": sector_count * sector_size,
                "filename": filename,
            }
        )

    ET.indent(root, space="  ")
    xml_path = output_dir / "tb371fc-critical-readback.xml"
    ET.ElementTree(root).write(xml_path, encoding="utf-8", xml_declaration=True)

    inventory_path = output_dir / "tb371fc-critical-readback.json"
    inventory_path.write_text(
        json.dumps(inventory, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )

    total = sum(int(item["expected_bytes"]) for item in inventory)
    print(f"Generated {xml_path}")
    print(f"Generated {inventory_path}")
    print(f"Read commands: {len(inventory)}")
    print(f"Expected output: {total} bytes ({total / 1024 / 1024:.1f} MiB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
