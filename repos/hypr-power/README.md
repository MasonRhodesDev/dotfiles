# hypr-power

Single-process power-management state machine for Hyprland on Framework 16.

## What it owns

- **Lid switch.** Holds a logind `handle-lid-switch:block` inhibitor so logind doesn't suspend on lid close. The FSM decides instead.
- **eDP-2 enable/disable.** Disabled when lid closed, re-enabled (via `hyprctl reload`) when lid opens. Hard invariant — re-asserted by a 5s reconciler and on `configreloaded` events.
- **Suspend grace.** Lid close → 30s window before suspending. Cancellable by lid reopen, monitor hotplug, or new idle inhibitor.
- **Idle-inhibitor awareness.** If an inhibitor is already active at lid close, media is paused (`playerctl --all-players pause`) and the countdown is deferred until the inhibitor releases.
- **Lock-before-suspend.** Calls `Session.Lock()` before `Manager.Suspend()`, waits up to 2s for `LockedHint=true`.
- **DPMS-off when locked + inhibitor.** With an active screen (`LID_OPEN` or `DOCKED`) and the session locked while an inhibitor is held, screens DPMS-off after 30s. Reverses on unlock or inhibitor release.
- **Input-device wake.** A pre/post systemd-sleep hook keeps `/sys/.../power/wakeup` enabled on USB hubs, the ZSA Voyager keyboard, and the Logitech Lightspeed mouse.

## Layout

```
hypr-power.py            single-file program with all subcommands
hypr-power.service       systemd --user unit
system-sleep-hook.sh     wrapper invoked by /usr/lib/systemd/system-sleep/
install.sh               idempotent installer
```

## Subcommands

```
hypr-power daemon              # run the FSM (systemd --user)
hypr-power sleep-hook pre|post # invoked by systemd-suspend (root)
hypr-power install             # symlink + drop systemd unit
hypr-power uninstall           # reverse install
hypr-power status              # systemctl + journalctl summary
```

## Install

```
./install.sh        # one sudo prompt, symlinks system bits
```

The installer migrates from the older standalone `hypr-fsm.service` and removes the orphan `~/.local/share/systemd-sleep-hooks/usb-wake`.

## Debug

```
journalctl --user -u hypr-power.service -f       # daemon log
sudo tail -f /var/log/hypr-power-sleep.log       # sleep hook log
```

## Dependencies

System: `hyprctl`, `playerctl`, `hyprlock` (via hypridle's `lock_cmd`), `pgrep`, `hypridle` (catches the logind Lock signal and runs hyprlock).
Python: `dbus-next` (Fedora `python3-dbus-next`).
