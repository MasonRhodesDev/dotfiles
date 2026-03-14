# Software Manifest

Locally built software installed on this system. For LLM context.

## Hyprland Ecosystem

All built from source at `~/repos/hypr/deps/` and installed to `/usr/local/`.

| Name | Version | Commit | Source |
|------|---------|--------|--------|
| Hyprland | 0.54.2 | 59f9f268 (v0.54.2) | git@github.com:hyprwm/Hyprland.git |
| hyprtoolkit | 0.5.3 | 9af245a (main) | git@github.com:hyprwm/hyprtoolkit.git |
| hyprlauncher | 0.1.5 | 114828a (main) | git@github.com:hyprwm/hyprlauncher.git |
| aquamarine | 0.10.0 | a20a0e6 (v0.10.0) | git@github.com:hyprwm/aquamarine.git |
| hyprcursor | 0.1.13 | 44e91d4 (v0.1.13) | git@github.com:hyprwm/hyprcursor.git |
| hyprgraphics | 0.5.0 | 4af02a3 (v0.5.0) | git@github.com:hyprwm/hyprgraphics.git |
| hyprlang | 0.6.8 | 3a1c1b2 (v0.6.8) | git@github.com:hyprwm/hyprlang.git |
| hyprutils | 0.11.0 | fe68648 (v0.11.0) | git@github.com:hyprwm/hyprutils.git |
| hyprwayland-scanner | 0.4.5 | fcca0c6 (v0.4.5) | git@github.com:hyprwm/hyprwayland-scanner.git |
| hyprwire | 0.3.0 | 37bc90e (v0.3.0) | git@github.com:hyprwm/hyprwire.git |
| hyprpwcenter | 0.1.2 | 987eed2 (main) | git@github.com:hyprwm/hyprpwcenter.git |
| hyprshutdown | 0.1.0 | faec850 (main) | git@github.com:hyprwm/hyprshutdown.git |

## Local Patches

### hyprtoolkit — absolute icon path support

**File:** `~/repos/hypr/deps/hyprtoolkit/src/system/SystemIcon.cpp`

**Issue:** `CSystemIconDescription` only handles icon theme names (e.g. `firefox`), but the freedesktop Desktop Entry spec allows `Icon=` to be an absolute path (e.g. `/usr/share/pixmaps/slack.png`). Apps like Slack use absolute paths and their icons don't render.

**Fix:** Early return in the constructor when the name starts with `/` — check if the file exists and use it directly, bypassing theme lookup.

**Check on update:** This may be fixed upstream in future hyprtoolkit releases. Test by searching Slack in hyprlauncher after updating — if the icon shows without this patch, it's been fixed upstream. Related: [hyprwm/hyprlauncher#132](https://github.com/hyprwm/hyprlauncher/issues/132)

## Custom Tools

| Name | Version | Commit | Source |
|------|---------|--------|--------|
| lmtt | 0.1.0 | a8e7462 | git@github.com:MasonRhodesDev/linux-multi-theme-toggle.git |
| voice-dictation | 0.1.0 | 1a6720e | git@github.com:MasonRhodesDev/wayland-voice-dictation.git |
| logind-idle-control | 0.1.0 | 93a50bf | git@github.com:MasonRhodesDev/logind-idle-control.git |
