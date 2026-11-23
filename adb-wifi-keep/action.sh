#!/system/bin/sh
# Magisk Action button: switches the keeper on or off, at once, without a reboot.
MODDIR=${0%/*}
. "$MODDIR/common.sh"
if [ -f "$ENABLED" ]; then turn_off; else turn_on; fi
