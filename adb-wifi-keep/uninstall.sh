#!/system/bin/sh
# Puts the saved settings back when the module is removed while on.
# Magisk runs this early in boot, before the settings service exists, so the
# restore waits for boot to finish in the background. The functions are loaded
# first because the module directory is deleted right after this script.
MODDIR=${0%/*}
. "$MODDIR/common.sh"
[ -f "$ENABLED" ] || { rm -rf "$STATE"; exit 0; }
(
  until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 5; done
  turn_off
  rm -rf "$STATE"
) &
