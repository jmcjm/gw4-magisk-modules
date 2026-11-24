#!/system/bin/sh
# accelerometer_rotation turns itself back on (written by system_server with
# its default value 1, not by the user), so it is turned off after every boot.
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 5; done
settings put system accelerometer_rotation 0
