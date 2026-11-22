#!/system/bin/sh
# Kills cached processes of launcher apps after they have stayed in the
# background for IDLE_SECONDS. A process counts as cached when its
# oom_score_adj is at least CACHED_ADJ (not visible, no foreground service),
# which is the same state lmkd kills from, so SIGKILL is safe here.
#
# Targets: every package with a LAUNCHER activity, minus the HOME package
# and KEEP. Background-only packages (watch faces, complication helpers,
# telephony) have no launcher icon and are never touched.
KEEP="com.samsung.android.wear.shealth com.google.android.gms"
IDLE_SECONDS=300
INTERVAL=60
CACHED_ADJ=900
REFRESH_LOOPS=30
STATE=/dev/idle-reaper

packages_for() {
  cmd package query-activities --brief -a android.intent.action.MAIN -c "$1" 2>/dev/null \
    | grep '/' | sed 's#^ *##; s#/.*##' | sort -u
}

build_list() {
  home=$(packages_for android.intent.category.HOME)
  PKGS=""
  for pkg in $(packages_for android.intent.category.LAUNCHER); do
    case " $KEEP $home " in
      *" $pkg "*) continue ;;
    esac
    PKGS="$PKGS $pkg"
  done
  log -t idle-reaper "watching:$PKGS"
}

until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 5; done
sleep 30
mkdir -p "$STATE"
loops=0

while true; do
  if [ $((loops % REFRESH_LOOPS)) -eq 0 ]; then
    build_list
  fi
  loops=$((loops + 1))
  now=$(cut -d. -f1 /proc/uptime)
  for pkg in $PKGS; do
    f="$STATE/$pkg"
    pid=$(pidof "$pkg")
    adj=""
    [ -n "$pid" ] && adj=$(cat "/proc/$pid/oom_score_adj" 2>/dev/null)
    if [ -z "$adj" ] || [ "$adj" -lt "$CACHED_ADJ" ]; then
      rm -f "$f"
      continue
    fi
    # The file holds "<pid> <uptime when it became cached>".
    old_pid=""
    since=""
    [ -f "$f" ] && read -r old_pid since < "$f"
    if [ "$old_pid" != "$pid" ]; then
      echo "$pid $now" > "$f"
      continue
    fi
    if [ $((now - since)) -ge "$IDLE_SECONDS" ]; then
      kill -9 "$pid" && log -t idle-reaper "killed $pkg (pid $pid, cached for $((now - since)) s)"
      rm -f "$f"
    fi
  done
  sleep "$INTERVAL"
done
