#!/system/bin/sh
# Slate mode does not survive a reboot, but make sure charging is not left
# blocked. The config in /data/adb/charge-limit goes with the module.
echo 0 > /sys/class/power_supply/battery/batt_slate_mode
rm -rf /data/adb/charge-limit
