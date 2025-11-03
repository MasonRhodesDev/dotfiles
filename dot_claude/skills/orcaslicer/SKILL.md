---
name: orcaslicer
description: Manage OrcaSlicer slicer profiles and E3V2 configurations. Use when working with slicer profiles, tuning print settings, comparing profiles, or troubleshooting G-code generation for the Ender 3 V2.
---

# OrcaSlicer Configuration Management

Expert assistance with OrcaSlicer slicer configuration, profile management, and G-code generation for the Ender 3 V2.

## Overview

This skill provides procedural knowledge for managing OrcaSlicer profiles and configurations. Use this skill when asked to:

- View or edit OrcaSlicer profiles (machine, filament, process)
- Compare profile settings or track changes
- Troubleshoot print quality issues related to slicer settings
- Backup or restore profile configurations
- Sync G-code between OrcaSlicer and Klipper
- Work with the E3V2-tagged custom profiles

## Configuration Locations

### Primary Directories

- **Main Config**: `~/.config/OrcaSlicer/`
- **App Settings**: `~/.config/OrcaSlicer/OrcaSlicer.conf`
- **Logs**: `~/.config/OrcaSlicer/log/`

### Profile Directories

**User Profiles** (customized settings):
- Machine: `~/.config/OrcaSlicer/user/default/machine/`
- Filament: `~/.config/OrcaSlicer/user/default/filament/`
- Process: `~/.config/OrcaSlicer/user/default/process/`

**System Profiles** (factory defaults):
- Machine: `~/.config/OrcaSlicer/system/Creality/machine/`
- Filament: `~/.config/OrcaSlicer/system/Creality/filament/`
- Process: `~/.config/OrcaSlicer/system/Creality/process/`

## E3V2 Custom Profiles

Three custom profiles are tagged with [E3V2]:

1. **[E3V2] Ender-3 V2** (machine) - Configured for Klipper at 192.168.1.23:7125
2. **[E3V2] PLA** (filament) - Tuned flow ratio (0.95) for the specific printer
3. **[E3V2] 0.20mm Structural** (process) - Enhanced strength with 35% infill, 6 top layers

## Common Tasks

### Viewing Profiles

```bash
# View E3V2 machine profile
cat ~/.config/OrcaSlicer/user/default/machine/[E3V2]\ Ender-3\ V2.json | jq .

# View E3V2 PLA filament settings
cat ~/.config/OrcaSlicer/user/default/filament/[E3V2]\ PLA.json | jq .

# View structural process profile
cat ~/.config/OrcaSlicer/user/default/process/[E3V2]\ 0.20mm\ Structural.json | jq .

# List all user profiles
ls -la ~/.config/OrcaSlicer/user/default/*/
```

### Editing Profiles

**Important:** Close OrcaSlicer before editing JSON files directly.

```bash
# Edit machine profile (use your editor)
vim ~/.config/OrcaSlicer/user/default/machine/[E3V2]\ Ender-3\ V2.json

# Validate JSON syntax after editing
jq . ~/.config/OrcaSlicer/user/default/machine/[E3V2]\ Ender-3\ V2.json > /dev/null

# Changes take effect when OrcaSlicer is restarted
```

### Backing Up Profiles

Use the backup script:

```bash
scripts/backup_profiles.sh
```

Or manually:

```bash
# Backup all user profiles
cp -r ~/.config/OrcaSlicer/user/default ~/backups/orcaslicer-$(date +%Y%m%d-%H%M%S)

# Backup just E3V2 profiles
mkdir -p ~/backups/orcaslicer-e3v2-$(date +%Y%m%d-%H%M%S)
cp ~/.config/OrcaSlicer/user/default/machine/\[E3V2\]* ~/backups/orcaslicer-e3v2-*/
cp ~/.config/OrcaSlicer/user/default/filament/\[E3V2\]* ~/backups/orcaslicer-e3v2-*/
cp ~/.config/OrcaSlicer/user/default/process/\[E3V2\]* ~/backups/orcaslicer-e3v2-*/
```

### Comparing Profiles

Use the comparison script:

```bash
scripts/compare_profiles.sh "profile1.json" "profile2.json"
```

Or manually:

```bash
# Compare two process profiles
diff <(jq -S . ~/.config/OrcaSlicer/user/default/process/[E3V2]\ 0.20mm\ Structural.json) \
     <(jq -S . ~/.config/OrcaSlicer/system/Creality/process/0.20mm\ Standard\ @Creality\ Ender3V2.json)
```

### Checking Klipper Sync

Use the sync checker:

```bash
scripts/check_klipper_sync.sh
```

This verifies that OrcaSlicer's machine profile G-code matches the Klipper configuration.

### Viewing Logs

```bash
# View recent OrcaSlicer logs
tail -100 ~/.config/OrcaSlicer/log/orcaslicer.log

# Search for errors
grep -i error ~/.config/OrcaSlicer/log/orcaslicer.log
```

### Creating Profile Variants

```bash
# Duplicate existing profile as starting point
cd ~/.config/OrcaSlicer/user/default/process/
cp "[E3V2] 0.20mm Structural.json" "[E3V2] 0.20mm High Speed.json"

# Edit the new profile (change name, settings, etc.)
vim "[E3V2] 0.20mm High Speed.json"
```

## Integration with Klipper

The [E3V2] machine profile connects to Klipper/Moonraker at:
- **Host**: `192.168.1.23:7125`
- **Note**: This should match `printer@192.168.1.216` from the klipper skill

### Important Considerations

1. **G-code Macros**: Machine profile includes START_PRINT and END_PRINT macros that must exist in Klipper config
2. **Print Host Address**: Verify IP `192.168.1.23` resolves to printer at `192.168.1.216`
3. **Upload Directory**: G-code appears in `~/printer_ender3v2_data/gcodes/` on the printer
4. **Macro Parameters**: START_PRINT receives `EXTRUDER_TEMP`, `BED_TEMP`, `CHAMBER_TEMP`

## Profile Inheritance

OrcaSlicer profiles use inheritance to reduce duplication:

```
[E3V2] Ender-3 V2 (user)
    └─ inherits: Creality Ender-3 V2 0.4 nozzle (system)

[E3V2] PLA (user)
    └─ inherits: Creality Generic PLA (system)

[E3V2] 0.20mm Structural (user)
    └─ inherits: 0.20mm Standard @Creality Ender3V2 (system)
```

User profiles only store settings that differ from their parent.

## Best Practices

1. **Always backup before editing**: `scripts/backup_profiles.sh`
2. **Close OrcaSlicer** before editing JSON files directly
3. **Test incrementally**: Change one setting at a time and test print
4. **Use inheritance**: Create new profiles that inherit from existing ones
5. **Document changes**: Add notes in profile descriptions
6. **Validate JSON**: Use `jq` to check syntax after manual edits
7. **Keep system profiles**: Don't modify `system/` files - they're overwritten on updates

## Reference Material

For detailed information, refer to:

- `references/profile_types.md` - Machine, filament, and process profile details
- `references/e3v2_profiles.md` - Complete E3V2 profile specifications
- `references/setting_keys.md` - Common setting keys and their meanings
- `references/troubleshooting.md` - Common issues and solutions

## Resources

### scripts/

- `backup_profiles.sh` - Automated profile backup with timestamps
- `compare_profiles.sh` - Profile comparison with readable diff output
- `check_klipper_sync.sh` - Verify OrcaSlicer/Klipper G-code sync

### references/

- `profile_types.md` - Detailed explanation of profile types and inheritance
- `e3v2_profiles.md` - Complete E3V2 profile documentation
- `setting_keys.md` - Reference for common setting keys
- `troubleshooting.md` - Common problems and solutions
