"""Extract the GPL driver from the archived public v3 mailing-list patch."""
from html.parser import HTMLParser
from pathlib import Path


class PreText(HTMLParser):
    def __init__(self):
        super().__init__()
        self.depth = 0
        self.parts = []

    def handle_starttag(self, tag, attrs):
        if tag == "pre":
            self.depth += 1

    def handle_endtag(self, tag):
        if tag == "pre":
            self.depth -= 1

    def handle_data(self, data):
        if self.depth:
            self.parts.append(data)


base = Path("D:/TB371FC-builds/r232-dp-prep")
parser = PreText()
parser.feed((base / "ps5169-v3.html").read_text(encoding="utf-8"))
patch = "".join(parser.parts)
marker = "diff --git a/drivers/usb/typec/mux/ps5169.c"
assert marker in patch, "Not the expected v3 patch"
section = patch.split(marker, 1)[1].split("\ndiff --git ", 1)[0]
lines = [line[1:] for line in section.splitlines()
         if line.startswith("+") and not line.startswith("+++")]
source = "\n".join(lines) + "\n"
assert len(lines) == 592, f"Unexpected driver length: {len(lines)}"
assert "SPDX-License-Identifier: GPL-2.0" in source
assert "ps5169" in source
(base / "ps5169.c").write_text(source, encoding="utf-8", newline="\n")
print(f"Extracted {len(lines)} lines to {base / 'ps5169.c'}")
