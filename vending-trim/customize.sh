# Magisk runs this during installation, on the watch.
#
# The overlay of /system/etc/sysconfig/clockwork.xml is built from the
# file of the firmware the module is installed on, without the Play Store
# power-save entry. The file differs between firmware versions, so a copy
# taken from one firmware would drop or add unrelated entries on another.

SRC=/system/etc/sysconfig/clockwork.xml
DST=$MODPATH/system/etc/sysconfig/clockwork.xml
ENTRY='allow-in-power-save-except-idle package="com.android.vending"'

[ -f "$SRC" ] || abort "! $SRC not found"
grep -q "$ENTRY" "$SRC" || abort "! $SRC has no Play Store power-save entry"

mkdir -p "${DST%/*}"
grep -v "$ENTRY" "$SRC" > "$DST"
set_perm "$DST" 0 0 0644
ui_print "- clockwork.xml built from this firmware, Play Store entry removed"
