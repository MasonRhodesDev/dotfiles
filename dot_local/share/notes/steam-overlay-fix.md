# Steam Overlay Issues - Investigation Log

**Date:** 2026-02-07
**System:** Arch Linux / Wayland / Hyprland (mason-desktop)

## Original Problem

Steam overlay welcome notification ("Access Steam features from the overlay while playing. Press Shift+Tab to begin") appeared repeatedly/constantly during gameplay.

## Investigation Summary

### What We Tried

1. **Checked for config corruption** - Found `gameoverlayui.so` had file size mismatch in logs
2. **Removed corrupted overlay library** - Steam redownloaded it, didn't fix issue
3. **Searched for tutorial "seen" flag** - None exists in VDF config files
4. **Cleared htmlcache LocalStorage** - **This fixed the constant popup**

### Fix Applied

```bash
steam -shutdown
sleep 3
rm -rf ~/.local/share/Steam/config/htmlcache/Default/Local\ Storage/leveldb
steam
```

### Results

| Issue | Status |
|-------|--------|
| Performance lag on overlay popup | **Fixed** |
| Notification appearing constantly | **Fixed** |
| Tutorial shows once per game launch | **Not fixed** (see below) |

## Remaining Issue: Tutorial Shows Every Launch

### Findings

- The overlay tutorial should show **once** then never again
- No config flag exists to mark "tutorial seen" in:
  - `localconfig.vdf`
  - `registry.vdf`
  - `config.vdf`
- Similar "hint dismissed" flags exist (e.g., `bRemotePlayLinkHintDismissed`) but not for overlay tutorial
- Per-game overlay state (`OverlaySavedDataV2_<APPID>_windows`) only stores panel visibility, not tutorial state
- The tutorial state was likely stored in LocalStorage (which we cleared)

### Root Cause Theory

LocalStorage leveldb isn't persisting the tutorial "seen" state between Steam sessions. Possible causes:
- Permissions issue on leveldb directory
- Steam not flushing leveldb properly on shutdown
- Wayland/Linux-specific bug

### Status

**Not a known tracked bug** on GitHub (ValveSoftware/steam-for-linux).
Users have complained on Steam Community forums but it's treated as a "feature request" to add a toggle, not as a bug report.

### Workarounds

1. **Disable all notification toasts**: Steam → Settings → Notifications → "Show Notification Toasts" → Never
2. **Disable overlay entirely**: Steam → Settings → In-Game → Uncheck "Enable the Steam Overlay"
3. **Live with it** until Valve fixes

### Potential Next Steps

- File bug report on GitHub with reproduction steps
- Monitor leveldb for permission issues
- Test if running Steam with different env vars helps

## Files Investigated

- `~/.local/share/Steam/userdata/<ID>/config/localconfig.vdf`
- `~/.local/share/Steam/config/config.vdf`
- `~/.local/share/Steam/registry.vdf`
- `~/.local/share/Steam/config/htmlcache/Default/Local Storage/leveldb/`
- `~/.local/share/Steam/logs/bootstrap_log.txt`

## Related Links

- [Steam Community - Feature Request to disable notification](https://steamcommunity.com/discussions/forum/10/4030224882304463184/)
- [GitHub Issue #11269 - Overlay notifications causing freezes](https://github.com/ValveSoftware/steam-for-linux/issues/11269)
