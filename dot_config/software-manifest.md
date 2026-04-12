# Software Manifest

Locally built software installed on this system. For LLM context.

## Hyprland Ecosystem

All built from source at `~/repos/hypr/deps/` and installed to `/usr/local/`.

| Name | Version | Commit | Source |
|------|---------|--------|--------|
| Hyprland | 0.53.0+r35 | f1652b2 (main) | git@github.com:hyprwm/Hyprland.git |
| hyprtoolkit | 0.5.2+r2 | d4e1603 (main) | git@github.com:hyprwm/hyprtoolkit.git |
| hyprlauncher | 0.1.5+r17 | 3c087c9 (main) | git@github.com:hyprwm/hyprlauncher.git |
| aquamarine | 0.10.0+r7 | 534c88e (main) | git@github.com:hyprwm/aquamarine.git |
| hyprcursor | 0.1.13 | 44e91d4 (v0.1.13) | git@github.com:hyprwm/hyprcursor.git |
| hyprgraphics | 0.5.0+r4 | 7c75487 (main) | git@github.com:hyprwm/hyprgraphics.git |
| hyprlang | 0.6.8 | 3a1c1b2 (v0.6.8) | git@github.com:hyprwm/hyprlang.git |
| hyprutils | 0.11.0+r3 | 51a4f93 (main) | git@github.com:hyprwm/hyprutils.git |
| hyprwayland-scanner | 0.4.5+r1 | b3b0f1f (main) | git@github.com:hyprwm/hyprwayland-scanner.git |
| hyprwire | 0.2.1+r29 | ad47486 (main) | git@github.com:hyprwm/hyprwire.git |
| hyprpwcenter | r23 | 9ebd1d6 (main) | git@github.com:hyprwm/hyprpwcenter.git |
| hyprshutdown | r18 | 813bd56 (main) | git@github.com:hyprwm/hyprshutdown.git |

## Local Patches

### hyprtoolkit — absolute icon path support

**File:** `~/repos/hypr/deps/hyprtoolkit/src/system/SystemIcon.cpp`

**Issue:** `CSystemIconDescription` only handles icon theme names (e.g. `firefox`), but the freedesktop Desktop Entry spec allows `Icon=` to be an absolute path (e.g. `/usr/share/pixmaps/slack.png`). Apps like Slack use absolute paths and their icons don't render.

**Fix:** Early return in the constructor when the name starts with `/` — check if the file exists and use it directly, bypassing theme lookup.

**Check on update:** This may be fixed upstream in future hyprtoolkit releases. Test by searching Slack in hyprlauncher after updating — if the icon shows without this patch, it's been fixed upstream. Related: [hyprwm/hyprlauncher#132](https://github.com/hyprwm/hyprlauncher/issues/132)

## Custom Tools

| Name | Version | Commit | Source |
|------|---------|--------|--------|
| lmtt | 0.1.0 | 7adc359 | git@github.com:MasonRhodesDev/linux-multi-theme-toggle.git |
| voice-dictation | 0.2.0 | 854e73c | git@github.com:MasonRhodesDev/wayland-voice-dictation.git |
| logind-idle-control | 0.1.0 | 93a50bf | git@github.com:MasonRhodesDev/logind-idle-control.git |
