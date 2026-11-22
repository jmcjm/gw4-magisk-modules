# Magisk modules for the Galaxy Watch 4 (SM-R870)

Small Magisk modules used on a rooted Galaxy Watch 4 (SM-R870, One UI 8 Watch, firmware `R870XXS2JZG3`).

| Module | What it does |
|---|---|
| `vending-trim` | Keeps the Play Store out of the background |
| `idle-reaper` | Kills launcher apps that have been in the background for 5 minutes |

Build the zips with `./build.sh` (output in `out/`), then install them with `magisk --install-module <zip>` as root or from the Magisk app, and reboot.

## vending-trim

On this watch the Play Store kept three processes alive (about 190 MB) because Wear OS whitelists it for power save and it runs several background services.

- `system/etc/sysconfig/clockwork.xml` overlays the system file of the same name, without the `allow-in-power-save-except-idle` entry for `com.android.vending`. **The overlay replaces the whole file**: it is a copy of the file from `R870XXS2JZG3` with one line removed. On other firmware, take that firmware's own file and remove the same line, or the overlay will drop or add unrelated entries.
- `clockwork.xml` is derived from the original Samsung firmware. Its copyright ownership and license have not been established; rights may belong to Samsung and other respective rights holders.
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
