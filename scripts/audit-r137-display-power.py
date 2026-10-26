#!/usr/bin/env python3
"""Resolve actual DT display supplies and report required provider, no writes."""
import argparse
import json
import re
import subprocess

p = argparse.ArgumentParser()
p.add_argument('dtb')
p.add_argument('--require-closure', action='store_true')
a = p.parse_args()
text = subprocess.check_output(['dtc', '-q', '-I', 'dtb', '-O', 'dts', a.dtb], text=True)
nodes = {}
stack = []
for line in text.splitlines():
    line = line.strip()
    if line.endswith(' {'):
        stack.append(line[:-2].strip())
        nodes['/' + '/'.join(stack[1:])] = {}
    elif line == '};':
        stack.pop()
    elif stack and line.endswith(';'):
        prop, sep, value = line[:-1].partition(' = ')
        nodes['/' + '/'.join(stack[1:])][prop] = value if sep else True

def cells(s):
    return [int(x, 0) for x in re.findall(r'0x[0-9a-fA-F]+|\b[0-9]+\b', s)]

phandles = {cells(v['phandle'])[0]: k for k, v in nodes.items() if 'phandle' in v}
mdss = next(k for k in nodes if k.endswith('/display-subsystem@ae00000'))
targets = [(mdss + '/dsi@ae94000', 'vdda-supply'),
           (mdss + '/dsi@ae96000', 'vdda-supply'),
           (mdss + '/phy@ae94400', 'vdds-supply'),
           (mdss + '/phy@ae96400', 'vdds-supply'),
           (mdss + '/dsi@ae94000/panel@0', 'vddio-supply')]
result = []
for consumer, prop in targets:
    supplier = phandles[cells(nodes[consumer][prop])[0]]
    data = nodes[supplier]
    parent = supplier.rsplit('/', 1)[0]
    result.append({'consumer': consumer, 'supply': prop, 'provider': supplier,
                   'name': data.get('regulator-name'),
                   'min_uV': cells(data['regulator-min-microvolt'])[0],
                   'max_uV': cells(data['regulator-max-microvolt'])[0],
                   'parent_compatible': nodes[parent].get('compatible')})
print(json.dumps(result, indent=2))
assert {r['name'].strip('"') for r in result} == {'vreg_l5a_0p88', 'vreg_l9a_1p2', 'vreg_l14a_1p8'}
print('PASS: three actual display suppliers resolved; qcom RPMh regulator driver required.')
print('WARNING: DT constraints are not measured stock voltages; power-up needs separate validation.')
for address, expected in [('994000', ['gpio12', 'gpio13']), ('a8c000', ['gpio60', 'gpio61'])]:
    consumer = next(k for k in nodes if k.endswith('/i2c@' + address))
    pinstate = phandles[cells(nodes[consumer]['pinctrl-0'])[0]]
    actual = re.findall(r'gpio\d+', nodes[pinstate]['pins'])
    assert actual == expected, (consumer, pinstate, actual)
    print(f'PASS: physical I2C@{address} -> {pinstate}: {actual}')

# Resolve input supplies too: registering an LDO is not enough when its input
# buck regulator is disabled. Mappings are from6.12 pm8150_vreg_data.
input_groups = {'ldo5': 'vdd-l3-l4-l5-l18', 'ldo9': 'vdd-l6-l9',
                'ldo14': 'vdd-l7-l12-l14-l15'}
closure = set()
def upstream(node):
    if node in closure:
        return
    closure.add(node)
    data = nodes[node]
    parent, child = node.rsplit('/', 1)
    prop = input_groups.get(child)
    if child.startswith('smps'):
        prop = 'vdd-s' + child[4:]
    if prop:
        handle = cells(nodes[parent][prop + '-supply'])[0]
        upstream(phandles[handle])
    elif 'vin-supply' in data:
        upstream(phandles[cells(data['vin-supply'])[0]])

for row in result:
    upstream(row['provider'])
missing = []
for node in sorted(closure):
    data = nodes[node]
    disabled = data.get('status') == '"disabled"'
    print('POWER_CLOSURE', node, data.get('regulator-name'), 'DISABLED' if disabled else 'available')
    if disabled:
        missing.append(node)
if a.require_closure:
    assert not missing, f'missing upstream regulators: {missing}'
    print('PASS: entire display input-power closure available')
elif missing:
    print('FAIL: display LDOs have unavailable upstream input rails:', missing)
