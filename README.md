# Magisk modules for the Galaxy Watch 4 (SM-R870)

Small Magisk modules used on a rooted Galaxy Watch 4 (SM-R870). Used on One UI 8 Watch (`R870XXS2JZG3`) and One UI 6 Watch (`R870XXU1IYI1`).

| Module | What it does |
|---|---|
| `vending-trim` | Keeps the Play Store out of the background |
| `idle-reaper` | Kills launcher apps that have been in the background for 5 minutes |
| `adb-wifi-keep` | Keeps Wi-Fi on and ADB on TCP 5555 with key authentication, switched with the Action button |

Build the zips with `./build.sh` (output in `out/`), then install them with `magisk --install-module <zip>` as root or from the Magisk app, and reboot.

## vending-trim

On this watch the Play Store kept three processes alive (about 190 MB) because Wear OS whitelists it for power save and it runs several background services.

- `customize.sh`, at installation: copies the firmware's own `/system/etc/sysconfig/clockwork.xml` into the module without the `allow-in-power-save-except-idle` entry for `com.android.vending`. Magisk then overlays the system file with that copy. The file differs between firmware versions (`R870XXS2JZG3` and `R870XXU1IYI1` differ in several broadcast entries), so it is built on the watch instead of being shipped. After a firmware update, reinstall the module.
- `service.sh`, after boot: disables the quick-launch, cross-profile and multi-user components of the Play Store, sets `RUN_ANY_IN_BACKGROUND` and `RUN_IN_BACKGROUND` to `ignore`, puts it in the `rare` standby bucket and stops it.
- `uninstall.sh` re-enables the components and the app ops.

Side effect: installs pushed from the phone can wait until the Play Store is opened on the watch.

Verified after a reboot: no Play Store processes, standby bucket 40.

## idle-reaper

Every 60 seconds it reads `oom_score_adj` of each launcher app's process (one `/proc` read per app; no `dumpsys`). A process that has stayed cached (`oom_score_adj` ≥ 900: not visible, no foreground service) for 5 minutes gets `SIGKILL`, the same way `lmkd` kills cached processes, only earlier, before the app ends up in zram. The recents entry stays; the app starts cold next time.

- Targets: every package with a `LAUNCHER` activity, minus the home screen and `KEEP` (`com.samsung.android.wear.shealth` and `com.google.android.gms`, whose processes must stay for workouts and phone sync). The list is rebuilt every 30 rounds.
- Background-only packages (watch faces, complication helpers, telephony) have no launcher entry and are never touched.
- `sleep` does not wake the watch from suspend.
- Kills are logged under the `idle-reaper` logcat tag; `watching:` lists the current targets.

Settings are at the top of `service.sh` (`KEEP`, `IDLE_SECONDS`, `INTERVAL`).

## adb-wifi-keep

Wireless debugging on Wear OS changes its port, forgets pairings, and the WifiMediator turns Wi-Fi off whenever the phone is in Bluetooth range. This module replaces it with plain ADB over TCP on a fixed port, switched on and off with the **Action** button in the Magisk app, at once and without a reboot. Nothing runs in the background.

On:
- `cw_disable_wifimediator=1` and `clockwork_wifi_setting=on`, so Wear OS stops turning Wi-Fi off; Wi-Fi is switched on.
- `adb_allowed_connection_time=0`, so ADB key authorizations never expire.
- The public keys in `adb_keys` (the module's copy) are added to `/data/misc/adb/adb_keys`, so those computers connect without a prompt on the watch. Add a computer by appending its `~/.android/adbkey.pub` and rebuilding.
- adbd listens on TCP 5555. On a user build SELinux keeps adbd from reading `persist.adb.tcp.port`, so `service.sh` sets `service.adb.tcp.port` once at every boot instead.

Off: the settings saved when it was switched on are put back and adbd stops listening on TCP. That cuts off an ADB session running over Wi-Fi; switch it back on from the watch.

The state lives in `/data/adb/adb-wifi-keep/` (`enabled`, `saved`), outside the module directory, so updating the module keeps it. Removing the module while on restores the settings after the next boot.

Battery: Wi-Fi stays on, and an open ADB connection wakes the SoC on every TCP ACK from the computer. Run `adb disconnect` when you are not working.
