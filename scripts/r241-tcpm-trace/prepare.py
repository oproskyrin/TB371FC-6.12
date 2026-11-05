"""Read-only instrumentation in a PRIVATE R240-derived TCPM copy."""
from pathlib import Path
import sys
p = Path(sys.argv[1])
assert p.parent.name.startswith('r241-tcpm-trace.')
s = p.read_text()
anchor = '''\ttcpm_log(port, "PD RX, header: %#x [%d]", le16_to_cpu(msg->header),
\t\t port->attached);'''
assert s.count(anchor) == 1
trace = '''
    /* Diagnostic only: no state transitions or protocol response changes. */
    dev_info_ratelimited(port->dev,
        "R241 RX header=%04x type=%u count=%u state=%s attached=%d dr=%d pr=%d sop=%d\\n",
        le16_to_cpu(msg->header), pd_header_type_le(msg->header), cnt,
        tcpm_states[port->state], port->attached, port->data_role,
        port->pwr_role, rx_sop_type);
'''
p.write_text(s.replace(anchor, anchor + '\n' + trace))
