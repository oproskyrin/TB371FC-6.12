#!/bin/sh
set -eu
test "$(uname -r)" = 6.12.114-tb371fc-r199+
test "$(cat /sys/module/r231_charge_keepalive/parameters/active)" = Y
test "$(cat /sys/module/r231_charge_keepalive/parameters/fault)" = 0
test "$(cat /sys/module/r231_charge_keepalive/parameters/pets)" -ge 30
src=/run/r231-stage
dest=/usr/local/lib/tb371fc/$(uname -r)
test "$(sha256sum "$src/r231-charge-keepalive.ko" | cut -d ' ' -f1)" = 66bf214f03a6f5c47e6c36d51f5d770dbbd4de0ba613bd52a027d4d856610ba7
# Unique new names; preserve any unexpected user-owned file instead of replacing.
for file in "$dest/r231-charge-keepalive.ko" /usr/local/sbin/tb371fc-r231-charge-load /etc/systemd/system/r231-charge-keepalive.service; do
 test ! -e "$file" || { echo "REFUSE existing file: $file"; exit 1; }
done
mkdir -p "$dest"
install -m0644 "$src/r231-charge-keepalive.ko" "$dest/"
install -m0755 "$src/r231-charge-load.sh" /usr/local/sbin/tb371fc-r231-charge-load
install -m0644 "$src/r231-charge-keepalive.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable r231-charge-keepalive.service
# Adopts the already validated module; does NOT interrupt charging to reload it.
systemctl start r231-charge-keepalive.service
systemctl is-active r231-charge-keepalive.service
sync
echo 'R231 persistent service installed; running module adopted, next boot not yet tested'
