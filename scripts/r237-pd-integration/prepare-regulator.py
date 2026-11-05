"""Extend only the private R203 provider copy with opt-in stock L2A."""
from pathlib import Path
import sys
p = Path(sys.argv[1])
assert p.parent.name.startswith("r237-usb-regulators.")
s = p.read_text()
old = '''\t\tif (!of_node_name_eq(node, "ldo9") &&
\t\t    !of_node_name_eq(node, "ldo18") &&
\t\t    !of_node_name_eq(node, "smps4"))'''
new = '''\t\tif (!of_node_name_eq(node, "ldo9") &&
\t\t    !of_node_name_eq(node, "ldo18") &&
\t\t    !of_node_name_eq(node, "smps4") &&
            !(of_node_name_eq(node, "ldo2") &&
              of_property_read_bool(dev->of_node, "tb371fc,r237-pd-ldo2")))'''
assert s.count(old) == 1
p.write_text(s.replace(old, new))
