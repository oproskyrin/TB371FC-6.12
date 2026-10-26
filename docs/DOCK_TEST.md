# USB-C dock validation

The available dock exposes USB, HDMI and Ethernet. It is useful both as a
hardware target and as a recovery console path: Ethernet plus SSH can retain
access even while the internal display is under development.

HDMI on this dock is expected to be a DisplayPort Alt Mode to HDMI bridge. The
tablet therefore needs the complete PM8150B Type-C/PD, DWC3, QMP combo-PHY,
MSM DisplayPort and ONNN redriver path before HDMI can work. The external
monitor refresh rate is independent of the internal 30/60/120/144 Hz panel.

## Safe order

1. Boot the console image without the dock and save
   `tb371fc-hardware-report` output.
2. Attach the unpowered dock. Verify Type-C role events, the USB hub and input
   devices with `dmesg -w` and `lsusb -t`.
3. Test one keyboard or mouse, then a read-only USB storage device. Do not
   mount Android partitions.
4. Connect Ethernet and inspect `ip link`, `ethtool -i INTERFACE` and
   `journalctl -u NetworkManager`. Expected common modules are `r8152` and
   `ax88179_178a`; both compile in the 7.1.8 module tree.
5. Test DHCP, local-gateway ping, SSH and `iperf3`. Record the dock USB VID:PID
   and Ethernet driver/firmware.
6. Attach dock power and verify sink current/voltage and thermal behaviour.
   Do not assume the community-reported 27 W result applies to this dock.
7. Attach one HDMI monitor at a conservative 1920x1080 60 Hz. Inspect
   `/sys/class/drm`, `drm_info` and kernel DP/Type-C logs before attempting a
   higher resolution.
8. Test HDMI hotplug, unplug, suspend/resume and dock power removal.
9. Test DisplayPort audio only after the DRM link is stable.

## Pass criteria

- the hub survives repeated attach/detach without controller resets;
- USB host/device role changes do not strand the diagnostic console;
- Ethernet transfers are stable and the interface returns after suspend;
- PD does not oscillate roles or exceed safe temperatures;
- the external connector is detected consistently and 1080p60 survives
  hotplug and suspend;
- every failure has a before/after hardware-report bundle and full `dmesg`.

Only after these pass should we test the monitor's native resolution, higher
external refresh rates, MST or simultaneous high-bandwidth USB and display.

In the temporary BusyBox diagnostic image use plain `lsusb`, `ip link` and
`udhcpc -i INTERFACE`; it does not contain the full `ethtool`/`drm_info`
userspace and intentionally does not request DHCP automatically. The complete
Arch console rootfs provides the richer commands used in the steps above.
