# Troubleshooting Guide

Common OrcaSlicer issues, their causes, and solutions for the E3V2 setup.

## Profile Issues

### Profile Not Appearing in OrcaSlicer

**Symptoms:**
- Profile exists in filesystem but not visible in GUI
- Dropdown doesn't show newly created profile
- Profile worked before but disappeared

**Causes:**
- JSON syntax error
- Profile in wrong directory
- OrcaSlicer cache issue
- Inheritance parent missing

**Solutions:**

```bash
# 1. Validate JSON syntax
jq . ~/.config/OrcaSlicer/user/default/machine/[E3V2]\ Ender-3\ V2.json

# If error, fix JSON and retry

# 2. Verify correct directory
ls -la ~/.config/OrcaSlicer/user/default/machine/
# Machine profiles should be in machine/
# Filament profiles in filament/
# Process profiles in process/

# 3. Check inheritance parent exists
cat profile.json | jq .inherits
# Verify parent profile exists in system/ or user/

# 4. Restart OrcaSlicer completely
killall orcaslicer
# Then relaunch

# 5. Clear OrcaSlicer cache (last resort)
rm -rf ~/.cache/orca-slicer/
# Restart OrcaSlicer
```

### Profile Inheritance Not Working

**Symptoms:**
- Child profile not picking up parent settings
- Settings different than expected
- Inheritance appears broken

**Causes:**
- Typo in `inherits` field
- Parent profile renamed/deleted
- Circular inheritance
- Wrong profile type inheritance

**Solutions:**

```bash
# Check inherits field spelling
cat profile.json | jq .inherits
# Must match parent name exactly (case-sensitive)

# Verify parent exists
find ~/.config/OrcaSlicer -name "*parent_name*"

# Check for circular inheritance (A inherits B, B inherits A)
# Profile A:
cat profileA.json | jq .inherits
# Output: "profileB"
# Profile B:
cat profileB.json | jq .inherits
# Should NOT be "profileA"

# Verify profile types match
# Machine profiles should inherit from machine profiles
# Filament from filament, process from process
```

### Settings Not Persisting

**Symptoms:**
- Changes made in GUI don't save
- Profile reverts to old settings
- Modifications disappear after restart

**Causes:**
- OrcaSlicer running when manually editing JSON
- File permissions issue
- Profile locked/read-only
- Wrong profile selected

**Solutions:**

```bash
# 1. Always close OrcaSlicer before manual JSON edits
killall orcaslicer

# 2. Check file permissions
ls -la ~/.config/OrcaSlicer/user/default/machine/
# Should be writable: -rw-r--r--

# Fix if needed:
chmod 644 ~/.config/OrcaSlicer/user/default/machine/*.json

# 3. Verify editing correct profile
# Check profile name in GUI matches filename exactly

# 4. Make sure not editing system profiles
# System profiles are read-only
# Create user profile copy instead:
cd ~/.config/OrcaSlicer/user/default/machine/
cp ../../system/Creality/machine/base_profile.json ./new_profile.json
```

## Print Host Connection Issues

### Cannot Connect to Printer

**Symptoms:**
- "Connection failed" error
- Cannot upload G-code
- Web interface works but OrcaSlicer doesn't
- Timeout when connecting

**Causes:**
- IP address mismatch
- Moonraker not running
- Port blocked by firewall
- Wrong authorization type

**Solutions:**

```bash
# 1. Verify printer IP address
# OrcaSlicer machine profile shows: 192.168.1.23:7125
# Klipper SSH: printer@192.168.1.216
# These should be the same printer

# Test connectivity:
ping 192.168.1.23
ping 192.168.1.216

# 2. Check Moonraker is running
ssh printer@192.168.1.216 "systemctl status moonraker"

# Should show: active (running)

# 3. Test Moonraker API directly
curl http://192.168.1.23:7125/server/info

# Should return JSON with server info

# 4. Check firewall
ssh printer@192.168.1.216 "sudo ufw status"

# Port 7125 should be allowed

# 5. Verify machine profile settings
cat ~/.config/OrcaSlicer/user/default/machine/[E3V2]\ Ender-3\ V2.json | jq .print_host

# Should be: "192.168.1.23:7125"

# Update if needed (close OrcaSlicer first):
# Edit JSON and change "print_host" value
```

### Upload Works But Print Doesn't Start

**Symptoms:**
- G-code uploads successfully
- File appears in Moonraker/Fluidd
- Print doesn't start automatically
- No error message

**Causes:**
- Expected behavior (auto-start not configured)
- Printer waiting for confirmation
- Printer busy with other command

**Solutions:**

This is normal behavior. After upload:

1. Go to printer web interface (Fluidd/Mainsail)
2. Select uploaded file
3. Click "Print" to start

To enable auto-start (optional):
```bash
# Edit moonraker.conf on printer
ssh printer@192.168.1.216
cd ~/printer_ender3v2_data/config
vim moonraker.conf

# Add or modify [file_manager]:
[file_manager]
enable_auto_start: True

# Restart Moonraker:
sudo systemctl restart moonraker
```

## G-code Generation Issues

### Macro Errors on Print Start

**Symptoms:**
- Print fails immediately after starting
- Klipper error: "Unknown command: START_PRINT"
- Macro parameter errors

**Causes:**
- START_PRINT macro missing in Klipper config
- Macro parameter mismatch
- G-code flavor misconfigured

**Solutions:**

```bash
# 1. Verify START_PRINT exists in Klipper
ssh printer@192.168.1.216
cd ~/printer_ender3v2_data/config
grep -r "START_PRINT" .

# Should find it in klipper-macros/start_end.cfg

# 2. Check machine profile start G-code
cat ~/.config/OrcaSlicer/user/default/machine/[E3V2]\ Ender-3\ V2.json | jq .machine_start_gcode

# Should include:
# START_PRINT EXTRUDER_TEMP=[nozzle_temperature] BED_TEMP=[bed_temperature]

# 3. Verify macro parameters match
# Klipper macro should accept EXTRUDER_TEMP and BED_TEMP

# 4. Check G-code flavor
cat ~/.config/OrcaSlicer/user/default/machine/[E3V2]\ Ender-3\ V2.json | jq .gcode_flavor

# Should be: "klipper"

# Fix if needed (close OrcaSlicer first):
# Edit JSON: "gcode_flavor": "klipper"
```

### First Layer Too Close/Far From Bed

**Symptoms:**
- Nozzle too close, filament scraping
- Nozzle too far, print not sticking
- Good bed level but wrong Z height

**Causes:**
- Z-offset in OrcaSlicer conflicts with Klipper
- Wrong initial layer height
- Both OrcaSlicer and Klipper applying offsets

**Solutions:**

**Best Practice**: Set Z-offset in Klipper only, not OrcaSlicer.

```bash
# 1. Check OrcaSlicer machine profile
cat ~/.config/OrcaSlicer/user/default/machine/[E3V2]\ Ender-3\ V2.json | jq .z_offset

# Should be: "0" or not present

# 2. Z-offset should be in Klipper config instead:
ssh printer@192.168.1.216
grep "z_offset" ~/printer_ender3v2_data/config/printer.cfg

# Should show: z_offset: 2.0 (or your calibrated value)

# 3. Adjust in Klipper, not OrcaSlicer:
# Use PROBE_CALIBRATE command in Klipper
# Or manually edit printer.cfg z_offset value

# 4. Verify initial layer height in process profile
cat ~/.config/OrcaSlicer/user/default/process/[E3V2]\ 0.20mm\ Structural.json | jq .initial_layer_height

# Should match or be slightly larger than layer_height
```

### Supports Not Generating

**Symptoms:**
- Model has overhangs but no supports
- "Generate supports" enabled but nothing appears
- Supports only partially generated

**Causes:**
- Support angle threshold too low
- Model orientation incorrect
- Support type incompatible with geometry
- Bug in support generation

**Solutions:**

```bash
# 1. Check support settings in process profile
cat ~/.config/OrcaSlicer/user/default/process/[E3V2]\ 0.20mm\ Structural.json | jq | grep support

# Key settings:
# "enable_support": "1" or true
# "support_angle": "45" (generates for angles > 45°)

# 2. Try different support type
# Edit profile: "support_type": "tree" or "normal"

# 3. Lower support angle threshold
# More supports: "support_angle": "30"
# Fewer supports: "support_angle": "60"

# 4. Check model orientation
# Rotate model in OrcaSlicer to reduce overhangs

# 5. Manual support placement
# Use "Paint-on supports" tool in OrcaSlicer
```

## Print Quality Issues

### Over-Extrusion / Parts Too Large

**Symptoms:**
- Parts larger than designed
- Rough surfaces
- Dimensional inaccuracy
- Holes too small

**Causes:**
- Flow ratio too high
- E-steps not calibrated in Klipper
- Nozzle diameter setting wrong

**Solutions:**

```bash
# 1. Check flow ratio in filament profile
cat ~/.config/OrcaSlicer/user/default/filament/[E3V2]\ PLA.json | jq .filament_flow_ratio

# Current: ["0.95"]
# Try lower: ["0.93"] (close OrcaSlicer first to edit)

# 2. Verify nozzle diameter in machine profile
cat ~/.config/OrcaSlicer/user/default/machine/[E3V2]\ Ender-3\ V2.json | jq .nozzle_diameter

# Should match actual: ["0.4"]

# 3. Print calibration cube
# Measure with calipers
# Should be 20.00mm × 20.00mm × 20.00mm

# 4. Calculate new flow:
# If cube measures 20.2mm:
# New flow = current_flow × (designed / actual)
# New flow = 0.95 × (20.0 / 20.2) = 0.94

# 5. Verify E-steps in Klipper (if flow < 0.90)
ssh printer@192.168.1.216
grep "rotation_distance" ~/printer_ender3v2_data/config/printer.cfg
# Should be calibrated for extruder
```

### Under-Extrusion / Weak Prints

**Symptoms:**
- Gaps between lines
- Weak layer adhesion
- Infill not solid
- Thin walls

**Causes:**
- Flow ratio too low
- Filament diameter wrong
- Partial nozzle clog
- Temperature too low

**Solutions:**

```bash
# 1. Increase flow ratio
cat ~/.config/OrcaSlicer/user/default/filament/[E3V2]\ PLA.json | jq .filament_flow_ratio

# Try higher: ["0.98"] or ["1.0"]

# 2. Check filament diameter setting
cat ~/.config/OrcaSlicer/user/default/filament/[E3V2]\ PLA.json | jq .filament_diameter

# Should be: ["1.75"]
# Measure actual filament with calipers

# 3. Check temperature
cat ~/.config/OrcaSlicer/user/default/filament/[E3V2]\ PLA.json | jq .nozzle_temperature

# Try 5-10°C higher if under-extruding

# 4. Check for partial clog
# Run cold pull or nozzle cleaning procedure
# Heat to 200°C, push filament manually
```

### Stringing / Oozing

**Symptoms:**
- Thin strings between parts
- Blobs on surface
- Filament oozing during travels

**Causes:**
- Retraction distance too short
- Retraction speed too slow
- Temperature too high
- Travel speed too slow

**Solutions:**

```bash
# 1. Check retraction settings
cat ~/.config/OrcaSlicer/user/default/machine/[E3V2]\ Ender-3\ V2.json | jq | grep retraction

# Current: retraction_length: ["1"]
# Try higher: ["1.5"] or ["2"]

# 2. Check retraction speed
# Try: retraction_speed: ["50"] or ["60"]

# 3. Lower temperature
cat ~/.config/OrcaSlicer/user/default/filament/[E3V2]\ PLA.json | jq .nozzle_temperature

# Try 5°C lower: ["195"] instead of ["200"]

# 4. Increase travel speed in process profile
cat ~/.config/OrcaSlicer/user/default/process/[E3V2]\ 0.20mm\ Structural.json | jq .travel_speed

# Try: "200" instead of "150"

# Note: Klipper with pressure advance handles retraction well
# Verify pressure advance is tuned in Klipper config
```

## File and System Issues

### OrcaSlicer Crashes on Startup

**Symptoms:**
- OrcaSlicer won't launch
- Immediate crash/exit
- Error messages in terminal

**Causes:**
- Corrupted config file
- Corrupted cache
- Missing dependencies
- Profile JSON syntax error

**Solutions:**

```bash
# 1. Check logs
tail -50 ~/.config/OrcaSlicer/log/orcaslicer.log

# Look for ERROR or exception messages

# 2. Backup and reset config (last resort)
mv ~/.config/OrcaSlicer ~/.config/OrcaSlicer.backup
# Relaunch OrcaSlicer (creates fresh config)

# 3. Restore profiles only
mkdir -p ~/.config/OrcaSlicer/user/default
cp -r ~/.config/OrcaSlicer.backup/user/default/* ~/.config/OrcaSlicer/user/default/

# 4. Check for JSON errors in profiles
for f in ~/.config/OrcaSlicer/user/default/*/*.json; do
    echo "Checking: $f"
    jq . "$f" > /dev/null || echo "ERROR in: $f"
done

# 5. Check dependencies (if on Linux)
ldd $(which orcaslicer) | grep "not found"
# Install any missing libraries
```

### Cannot Save Sliced G-code

**Symptoms:**
- "Save" button grayed out
- Save dialog doesn't appear
- Permission denied errors

**Causes:**
- No write permission to target directory
- Disk full
- Filename contains invalid characters

**Solutions:**

```bash
# 1. Check disk space
df -h ~

# 2. Check target directory permissions
ls -la ~/gcodes/
# Should be writable

# Fix if needed:
chmod 755 ~/gcodes

# 3. Avoid special characters in filename
# Use: model_name.gcode
# Not: model@#$%.gcode

# 4. Try saving to different location
# ~/Downloads/ usually has write access
```

## Klipper Integration Issues

### G-code Sync Problems

**Symptoms:**
- OrcaSlicer sends commands Klipper doesn't recognize
- Macros work in Klipper but not from OrcaSlicer
- Parameter errors in macros

**Causes:**
- Machine profile G-code doesn't match Klipper macros
- OrcaSlicer using wrong G-code flavor
- Macro parameters changed in Klipper

**Solutions:**

Use the sync checker script:

```bash
scripts/check_klipper_sync.sh
```

Manual verification:

```bash
# 1. Compare OrcaSlicer start G-code
cat ~/.config/OrcaSlicer/user/default/machine/[E3V2]\ Ender-3\ V2.json | jq .machine_start_gcode

# 2. Compare Klipper START_PRINT macro
ssh printer@192.168.1.216 "cat ~/printer_ender3v2_data/config/klipper-macros/start_end.cfg" | grep -A 20 "START_PRINT"

# 3. Verify parameters match
# OrcaSlicer sends: EXTRUDER_TEMP=[nozzle_temperature] BED_TEMP=[bed_temperature]
# Klipper should accept: EXTRUDER_TEMP and BED_TEMP as parameters
```

## Backup and Recovery

### Restoring from Backup

If profiles are corrupted or deleted:

```bash
# 1. Check for OrcaSlicer's auto-backups
ls -la ~/.config/OrcaSlicer/user_backup-*/

# 2. Restore from auto-backup
cp -r ~/.config/OrcaSlicer/user_backup-v2.3.2-dev/* ~/.config/OrcaSlicer/user/default/

# 3. Restore from manual backup
cp -r ~/backups/orcaslicer-YYYYMMDD-HHMMSS/* ~/.config/OrcaSlicer/user/default/

# 4. Restart OrcaSlicer
```

### Emergency Profile Reset

If all else fails, reset to E3V2 system defaults:

```bash
# 1. Backup current (possibly broken) profiles
mv ~/.config/OrcaSlicer/user/default ~/.config/OrcaSlicer/user/broken

# 2. Create new user directory
mkdir -p ~/.config/OrcaSlicer/user/default/{machine,filament,process}

# 3. Copy system E3V2 profiles as starting point
cp ~/.config/OrcaSlicer/system/Creality/machine/Creality\ Ender-3\ V2\ 0.4\ nozzle.json \
   ~/.config/OrcaSlicer/user/default/machine/[E3V2]\ Ender-3\ V2.json

cp ~/.config/OrcaSlicer/system/Creality/filament/Creality\ Generic\ PLA.json \
   ~/.config/OrcaSlicer/user/default/filament/[E3V2]\ PLA.json

cp ~/.config/OrcaSlicer/system/Creality/process/0.20mm\ Standard\ @Creality\ Ender3V2.json \
   ~/.config/OrcaSlicer/user/default/process/[E3V2]\ 0.20mm\ Structural.json

# 4. Edit profiles to customize
# Update names, remove "inherits" field, add customizations
```
