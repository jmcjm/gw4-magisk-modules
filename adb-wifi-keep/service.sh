#!/system/bin/sh
# Runs once late in boot. When the keeper is on: puts adbd on TCP 5555 (the
# property does not survive a reboot) and re-applies the settings in case a
# system update or a reset changed them. Nothing stays running.
MODDIR=${0%/*}
. "$MODDIR/common.sh"
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 5; done
if [ -f "$ENABLED" ]; then
  apply_settings
  install_keys
  svc wifi enable
  setprop service.adb.tcp.port "$PORT"
  restart_adbd
  set_description ON
else
  set_description OFF
fi
