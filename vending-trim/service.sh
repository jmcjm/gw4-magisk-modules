#!/system/bin/sh
# Runs late in boot. Applies runtime restrictions to the Play Store.
PKG=com.android.vending
COMPONENTS="
com.google.android.finsky.scheduler.process.quicklaunchimpl.PhoneskyJobServiceQuickLaunch
com.google.frameworks.client.data.android.server.play.QuickLaunchProcessEndpointService
com.google.android.finsky.devicemanagement.quicklaunchreceiver.DeviceManagementReceiver
com.google.android.finsky.crossprofile.ProfileStateService
com.google.android.finsky.multiusercoordinator.MultiUserCoordinatorService
"
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 5; done
sleep 30
for c in $COMPONENTS; do
  pm disable --user 0 "$PKG/$c" >/dev/null 2>&1
done
cmd appops set "$PKG" RUN_ANY_IN_BACKGROUND ignore
cmd appops set "$PKG" RUN_IN_BACKGROUND ignore
am set-standby-bucket "$PKG" rare
am force-stop "$PKG"
