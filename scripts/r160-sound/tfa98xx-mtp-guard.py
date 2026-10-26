#!/usr/bin/env python3
"""R161 safety: make the TFA98xx downstream driver unable to write amplifier MTP.
Blocks KEY2 unlock, tfa98xx_set_mtp() and tfa_dev_mtp_set(). Reading MTP still works."""
import sys
d = sys.argv[1]
p = d + '/tfa_dsp.c'
s = open(p).read()

def ins_after(sig, code):
    global s
    i = s.index(sig)
    j = s.index('{', i) + 1
    s = s[:j] + code + s[j:]

assert s.count('void tfa98xx_key2(struct tfa_device *tfa, int lock)\n{') == 1
ins_after('void tfa98xx_key2(struct tfa_device *tfa, int lock)\n{',
          '\n\tif (!lock) {\n\t\tpr_warn("tfa98xx: R161 MTP guard: KEY2 unlock blocked\\n");\n\t\treturn;\n\t}\n')
assert s.count('enum Tfa98xx_Error tfa98xx_set_mtp(struct tfa_device *tfa, uint16_t value,') == 1
ins_after('enum Tfa98xx_Error tfa98xx_set_mtp(struct tfa_device *tfa, uint16_t value,',
          '\n\tpr_warn("tfa98xx: R161 MTP guard: set_mtp(0x%x, 0x%x) blocked\\n", value, mask);\n\treturn Tfa98xx_Error_Bad_Parameter;\n')
assert s.count('enum tfa_error tfa_dev_mtp_set(struct tfa_device *tfa, enum tfa_mtp item,\n\t\t\t       int value)\n{') == 1
ins_after('enum tfa_error tfa_dev_mtp_set(struct tfa_device *tfa, enum tfa_mtp item,\n\t\t\t       int value)\n{',
          '\n\tpr_warn("tfa98xx: R161 MTP guard: mtp_set(%d, %d) blocked\\n", item, value);\n\treturn tfa_error_bad_param;\n')
open(p, 'w').write(s)
print('MTP guard applied')
