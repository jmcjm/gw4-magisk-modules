#!/system/bin/sh
# Stops charging at LIMIT and lets it resume at RESUME, by writing the
# battery driver's slate mode (1 = charging off while the charger stays
# connected, 0 = normal). There is no kernel charge limit on this watch.
#
# Nothing polls. One shell loop blocks on a FIFO fed by two busybox
# applets that themselves block in the kernel:
#   uevent    one line per change event of the battery power_supply
#   inotifyd  one line per change in the config directory or in the module
#             directory (Magisk's disable and remove flags)
# Every line re-reads capacity and status from sysfs and re-evaluates.
#
# If either applet dies, or the loop is stopped, slate mode goes back to 0,
# so charging is never left blocked without the watcher running.
MODDIR=${0%/*}

DEFAULT_LIMIT=90
DEFAULT_GAP=5          # RESUME = LIMIT - DEFAULT_GAP when not set
LIMIT_MIN=80
LIMIT_MAX=95
RESUME_MIN=50

CFGDIR=/data/adb/charge-limit
CFG=$CFGDIR/config
RUN=/dev/charge-limit
FIFO=$RUN/events
BAT=/sys/class/power_supply/battery
BAT_DEVPATH=/devices/platform/battery/power_supply/battery
B=/data/adb/magisk/busybox

say() { /system/bin/log -t charge-limit "$*" 2>/dev/null; }

slate() { cat "$BAT/batt_slate_mode" 2>/dev/null; }

set_slate() {
  [ "$(slate)" = "$1" ] && return 0
  echo "$1" > "$BAT/batt_slate_mode"
  say "slate $1 ($2)"
}

# Prints the digits of KEY=<digits> from the config file, or nothing.
cfg_value() {
  [ -f "$CFG" ] && sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\([0-9][0-9]*\)[[:space:]]*\$/\1/p" "$CFG" | tail -n 1
}

load_config() {
  limit=$(cfg_value LIMIT)
  [ -n "$limit" ] || limit=$DEFAULT_LIMIT
  [ "$limit" -lt "$LIMIT_MIN" ] && limit=$LIMIT_MIN
  [ "$limit" -gt "$LIMIT_MAX" ] && limit=$LIMIT_MAX
  resume=$(cfg_value RESUME)
  [ -n "$resume" ] || resume=$((limit - DEFAULT_GAP))
  [ "$resume" -ge "$limit" ] && resume=$((limit - 1))
  [ "$resume" -lt "$RESUME_MIN" ] && resume=$RESUME_MIN
  enabled=$(cfg_value ENABLED)
  [ "$enabled" = 0 ] || enabled=1
  # Magisk's own switch: disabled or marked for removal means no limit.
  [ -e "$MODDIR/disable" ] || [ -e "$MODDIR/remove" ] && enabled=0
  conf="enabled=$enabled limit=$limit resume=$resume"
  if [ "$conf" != "$last_conf" ]; then
    say "config: $conf"
    last_conf=$conf
  fi
}

evaluate() {
  if [ "$enabled" != 1 ]; then
    set_slate 0 "limit off"
  else
    cap=$(cat "$BAT/capacity")
    st=$(cat "$BAT/status")
    case "$st" in
      Charging|Full) charging=1 ;;
      *) charging=0 ;;
    esac
    if [ "$cap" -le "$resume" ]; then
      set_slate 0 "capacity $cap% <= $resume%, $st"
    elif [ "$cap" -ge "$limit" ] && [ "$charging" = 1 ]; then
      set_slate 1 "capacity $cap% >= $limit%, $st"
    fi
    # Between the two: keep the current state (hysteresis).
  fi
  printf '%s slate=%s\n' "$conf" "$(slate)" > "$RUN/status"
}

stop_all() {
  trap - EXIT
  for p in "$RUN/uevent.pid" "$RUN/inotifyd.pid"; do
    [ -f "$p" ] && kill "$(cat "$p")" 2>/dev/null
  done
  echo 0 > "$BAT/batt_slate_mode"
  rm -f "$FIFO" "$RUN"/*.pid
  echo "stopped slate=0" > "$RUN/status"
  say "stopped, slate 0"
}

mkdir -p "$CFGDIR" "$RUN"
# A second start (by hand, or a module update) replaces the running loop.
# Wait for the old one to finish its cleanup, which removes the files below.
if [ -f "$RUN/loop.pid" ]; then
  old=$(cat "$RUN/loop.pid")
  kill "$old" 2>/dev/null
  n=0
  while kill -0 "$old" 2>/dev/null && [ "$n" -lt 20 ]; do sleep 0.5; n=$((n + 1)); done
fi
echo $$ > "$RUN/loop.pid"
rm -f "$FIFO"
mkfifo "$FIFO"
trap stop_all EXIT
trap 'exit 0' TERM INT HUP

# uevent prints nothing into a pipe by itself, so it runs a handler per
# event; the handler inherits the FIFO as stdout.
(
  $B uevent /system/bin/sh -c '[ "$DEVPATH" = "$0" ] && echo battery' "$BAT_DEVPATH" &
  echo $! > "$RUN/uevent.pid"
  wait
  echo dead uevent
) > "$FIFO" &
(
  $B inotifyd - "$CFGDIR:wmnd" "$MODDIR:nd" &
  echo $! > "$RUN/inotifyd.pid"
  wait
  echo dead inotifyd
) > "$FIFO" &

say "started"
load_config
evaluate
while read -r kind what; do
  case "$kind" in
    dead) say "$what exited"; break ;;
    battery) ;;
    *) load_config ;;
  esac
  evaluate
done < "$FIFO"
exit 0
