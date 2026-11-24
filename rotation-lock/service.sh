#!/system/bin/sh
# accelerometer_rotation turns itself back on (written by system_server with
# its default value 1, not by the user). This turns it off after boot and
# checks it every INTERVAL seconds; each reset is logged under the
# rotation-lock tag, so the log shows when it happens.
INTERVAL=300

until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 5; done

while true; do
  if [ "$(settings get system accelerometer_rotation)" != "0" ]; then
    settings put system accelerometer_rotation 0
    log -t rotation-lock "auto-rotate was on, turned off (uptime $(cut -d' ' -f1 /proc/uptime) s)"
  fi
  sleep "$INTERVAL"
done
