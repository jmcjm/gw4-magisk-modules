#!/system/bin/sh
# Reverts the runtime restrictions applied by service.sh.
PKG=com.android.vending
COMPONENTS="
com.google.android.finsky.scheduler.process.quicklaunchimpl.PhoneskyJobServiceQuickLaunch
com.google.frameworks.client.data.android.server.play.QuickLaunchProcessEndpointService
com.google.android.finsky.devicemanagement.quicklaunchreceiver.DeviceManagementReceiver
com.google.android.finsky.crossprofile.ProfileStateService
com.google.android.finsky.multiusercoordinator.MultiUserCoordinatorService
"
for c in $COMPONENTS; do
  pm enable --user 0 "$PKG/$c" >/dev/null 2>&1
done
cmd appops set "$PKG" RUN_ANY_IN_BACKGROUND allow
cmd appops set "$PKG" RUN_IN_BACKGROUND allow
