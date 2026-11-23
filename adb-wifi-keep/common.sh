#!/system/bin/sh
# Shared by action.sh, service.sh and uninstall.sh. Sourced, not run.
#
# On:  adbd listens on TCP 5555, the Wear OS WifiMediator stops turning Wi-Fi
#      off, Wi-Fi is switched on, ADB key authorizations never expire, and the
#      keys shipped in adb_keys are authorized.
# Off: the settings saved when it was switched on are put back.
#
# Nothing runs in the background. The settings are persistent and written
# once. The port is not: on a user build SELinux keeps adbd from reading
# persist.adb.tcp.port, so service.sh sets service.adb.tcp.port once per boot.

MODDIR=${MODDIR:-${0%/*}}
STATE=/data/adb/adb-wifi-keep
SAVED=$STATE/saved
ENABLED=$STATE/enabled
PORT=5555
KEYS=/data/misc/adb/adb_keys

# Every settings call gets </dev/null: cmd hands its stdin to system_server,
# which cannot take a descriptor of a file under /data/adb, and the call then
# fails with FAILED_TRANSACTION. Inside a loop reading $SAVED that is the file.

# "<namespace> <key> <value when on>"
SETTINGS="
global cw_disable_wifimediator 1
system clockwork_wifi_setting on
global adb_allowed_connection_time 0
"

say() { echo "adb-wifi-keep: $*"; /system/bin/log -t adb-wifi-keep "$*" 2>/dev/null; }

restart_adbd() {
  # Drops the current ADB connection; reconnect afterwards.
  stop adbd
  start adbd
}

set_description() {
  sed -i "s|^description=.*|description=[$1] Keeps Wi-Fi on and adbd on TCP $PORT with key authentication. Toggle with the Action button.|" "$MODDIR/module.prop"
}

install_keys() {
  [ -f "$MODDIR/adb_keys" ] || return 0
  [ -f "$KEYS" ] || { touch "$KEYS"; chown system:shell "$KEYS"; chmod 0640 "$KEYS"; }
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    key=${line%% *}
    grep -qF -- "$key" "$KEYS" || echo "$line" >> "$KEYS"
  done < "$MODDIR/adb_keys"
  chown system:shell "$KEYS"
  chmod 0640 "$KEYS"
  restorecon "$KEYS" 2>/dev/null
}

apply_settings() {
  echo "$SETTINGS" | while read -r ns key val; do
    [ -n "$key" ] && settings put "$ns" "$key" "$val" </dev/null
  done
}

turn_on() {
  mkdir -p "$STATE"
  if [ ! -f "$SAVED" ]; then
    : > "$SAVED.tmp"
    echo "$SETTINGS" | while read -r ns key val; do
      [ -n "$key" ] && echo "$ns $key $(settings get "$ns" "$key" </dev/null)" >> "$SAVED.tmp"
    done
    mv "$SAVED.tmp" "$SAVED"
  fi
  apply_settings
  install_keys
  svc wifi enable
  setprop service.adb.tcp.port "$PORT"
  touch "$ENABLED"
  set_description ON
  say "on: Wi-Fi kept on, adbd on tcp $PORT"
  restart_adbd
}

turn_off() {
  if [ -f "$SAVED" ]; then
    while read -r ns key val; do
      if [ "$val" = null ] || [ -z "$val" ]; then
        settings delete "$ns" "$key" </dev/null >/dev/null
      else
        settings put "$ns" "$key" "$val" </dev/null
      fi
    done < "$SAVED"
    rm -f "$SAVED"
  fi
  setprop service.adb.tcp.port 0
  rm -f "$ENABLED"
  set_description OFF
  say "off: previous Wi-Fi and adb settings restored"
  restart_adbd
}
