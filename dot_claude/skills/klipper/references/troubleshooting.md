# Troubleshooting Guide

Common issues, their causes, and solutions for the Ender 3 V2 Klipper setup.

## BLTouch Issues

### BLTouch Not Deploying

**Symptoms:**
- "BLTouch failed to deploy" error
- Probe stays retracted during homing

**Causes:**
- Wiring issue (sensor or control pin)
- Incorrect pin configuration
- BLTouch needs reset

**Solutions:**
```bash
# Check pin configuration
klipper_read config/printer.cfg | grep -A 5 "\[bltouch\]"

# Expected configuration:
# sensor_pin: ^PB1
# control_pin: PB0

# Test BLTouch manually via web interface:
# BLTOUCH_DEBUG COMMAND=pin_down
# BLTOUCH_DEBUG COMMAND=pin_up
```

### BLTouch Z-Offset Issues

**Symptoms:**
- Nozzle too close or too far from bed
- First layer problems
- Nozzle crashes into bed

**Causes:**
- Incorrect z_offset value
- Z-offset not saved
- Bed mesh overriding offset

**Solutions:**
```bash
# Check current z_offset
klipper_read config/printer.cfg | grep "z_offset"

# Adjust z_offset (in printer.cfg):
# - Increase value to move nozzle away from bed
# - Decrease value to move nozzle closer to bed
# Current value: 2.0mm

# After changing, restart firmware:
# FIRMWARE_RESTART
```

**Safe Testing:**
1. Home printer: `G28`
2. Move to safe Z height: `G1 Z50`
3. Heat nozzle and bed to printing temps
4. Move to Z=0.1: `G1 Z0.1`
5. Check nozzle clearance with paper
6. Adjust z_offset and repeat

### BLTouch Probe Accuracy

**Symptoms:**
- Inconsistent bed mesh results
- "Probe accuracy out of range" errors
- Variable first layer quality

**Causes:**
- Loose BLTouch mount
- Bent probe pin
- Electromagnetic interference

**Solutions:**
```bash
# Test probe accuracy
# PROBE_ACCURACY

# Expected: standard deviation < 0.025mm
# If higher, check physical installation

# Check for loose screws
# Verify probe pin is straight
# Ensure wiring is not near stepper motors
```

## Bed Mesh Problems

### Mesh Min/Max Out of Range

**Symptoms:**
- "mesh_min/mesh_max out of range" error
- Bed leveling fails to start

**Causes:**
- Mesh coordinates don't account for probe offset
- Probe would move outside physical limits

**Solutions:**
```bash
# Check current mesh configuration
klipper_read config/printer.cfg | grep -A 10 "\[bed_mesh\]"

# Current values:
# mesh_min: 12, 22
# mesh_max: 187, 222

# Calculation:
# mesh_min = (desired_min_x - probe_offset_x, desired_min_y - probe_offset_y)
# mesh_max = (desired_max_x - probe_offset_x, desired_max_y - probe_offset_y)
#
# With probe offset of -48, +2:
# mesh_min = (60 - 48, 20 + 2) = (12, 22)
# mesh_max = (235 - 48, 220 + 2) = (187, 222)
```

### Bed Mesh Not Applied

**Symptoms:**
- First layer inconsistent despite mesh calibration
- Mesh calibration runs but doesn't affect prints

**Causes:**
- Mesh not loaded in START_PRINT
- No active mesh profile
- Mesh cleared by G28

**Solutions:**
```bash
# Check if mesh is active (via web interface or console):
# BED_MESH_PROFILE LOAD=default

# Verify START_PRINT loads mesh:
klipper_read config/klipper-macros/start_end.cfg | grep -i "bed_mesh"

# Ensure G28 uses relative_reference_index or doesn't clear mesh
```

## Variable File Issues

### Variable File Not Found

**Symptoms:**
- "Unable to load variable file" warning in logs
- Macros fail with variable errors
- Settings don't persist between restarts

**Causes:**
- Incorrect path in _km_options
- Path mismatch (printer_data vs printer_ender3v2_data)
- File doesn't exist yet

**Solutions:**
```bash
# Check configured path
klipper_read config/printer.cfg | grep "variable_file"

# Should be: ~/printer_data/variables.cfg
# NOT: ~/printer_ender3v2_data/variables.cfg

# Create file if missing:
klipper_exec "mkdir -p ~/printer_data"
klipper_exec "touch ~/printer_data/variables.cfg"
```

## Macro Errors

### Macro Not Found

**Symptoms:**
- "Unknown command: START_PRINT" error
- Slicer-triggered macro fails

**Causes:**
- Macro not included in printer.cfg
- Klipper-macros submodule not initialized
- Typo in macro name

**Solutions:**
```bash
# Check macro includes
klipper_read config/printer.cfg | grep "include.*macro"

# Expected:
# [include klipper-macros/*.cfg]

# Check if klipper-macros exists
klipper_list config/klipper-macros

# Initialize submodule if missing:
klipper_exec "cd config && git submodule update --init"
```

### Macro Variable Errors

**Symptoms:**
- "Variable not defined" errors
- Macros fail with missing parameters
- Unexpected macro behavior

**Causes:**
- Missing variable in globals.cfg
- Typo in variable name
- Wrong _km_options override

**Solutions:**
```bash
# Check variable definitions
klipper_read config/klipper-macros/globals.cfg | grep "variable_"

# Check user overrides
klipper_read config/printer.cfg | grep -A 20 "\[gcode_macro _km_options\]"

# Verify variable names match exactly (case-sensitive)
```

## Temperature Issues

### Temperature Not Reaching Target

**Symptoms:**
- Heater stuck below target temperature
- "Heater too slow" errors
- Print fails to start

**Causes:**
- PID tuning needed
- Thermistor issues
- Power supply problems

**Solutions:**
```bash
# Check recent temperature behavior in logs
klipper_exec "tail -200 logs/klippy.log | grep -i 'temperature\|heater'"

# Run PID tuning (via console):
# For hotend: PID_CALIBRATE HEATER=extruder TARGET=200
# For bed: PID_CALIBRATE HEATER=heater_bed TARGET=60

# After PID tuning, save config:
# SAVE_CONFIG
```

### Thermal Runaway

**Symptoms:**
- "Thermal runaway" error
- Heater shutdown
- Print stops abruptly

**Causes:**
- Thermistor loose
- Heater connection issue
- Actual thermal runaway (dangerous)

**Solutions:**
1. Immediately check printer physically
2. Verify thermistor is secure
3. Check heater connections
4. Review logs for temperature patterns:

```bash
klipper_exec "tail -500 logs/klippy.log | grep -E 'thermal|temperature'"
```

## Connection Issues

### MCU Connection Lost

**Symptoms:**
- "Lost communication with MCU" error
- Printer becomes unresponsive
- Need to restart Klipper

**Causes:**
- USB cable issue
- Electrical interference
- MCU crash

**Solutions:**
```bash
# Check recent logs for MCU errors
klipper_exec "tail -200 logs/klippy.log | grep -i 'mcu'"

# Restart Klipper (via web interface):
# FIRMWARE_RESTART

# If persistent, check USB connection physically
```

### Moonraker Connection Failed

**Symptoms:**
- OrcaSlicer can't connect to printer
- Web interface unreachable
- Upload fails

**Causes:**
- Moonraker not running
- Network issue
- Port mismatch

**Solutions:**
```bash
# Check if Moonraker is running
ssh printer@192.168.1.216 "systemctl status moonraker"

# Test connection from local machine
curl http://192.168.1.23:7125/server/info

# Verify IP addresses match:
# OrcaSlicer: 192.168.1.23:7125
# SSH: printer@192.168.1.216
# These should be the same printer

# Restart Moonraker if needed:
ssh printer@192.168.1.216 "sudo systemctl restart moonraker"
```

## Motion Issues

### Grinding/Skipping Steps

**Symptoms:**
- Grinding noise during movement
- Layer shifts
- Lost steps

**Causes:**
- Current too low
- Speed too high
- Mechanical obstruction

**Solutions:**
```bash
# Check motor current settings
klipper_read config/printer.cfg | grep "run_current"

# Check maximum velocity
klipper_read config/printer.cfg | grep "max_velocity\|max_accel"

# Reduce speed for testing:
# SET_VELOCITY_LIMIT VELOCITY=100 ACCEL=500
```

### Homing Fails

**Symptoms:**
- "Homing failed" error
- Endstop not triggering
- Axis moves wrong direction

**Causes:**
- Endstop wiring issue
- Incorrect endstop configuration
- Physical obstruction

**Solutions:**
```bash
# Check endstop status (via console):
# QUERY_ENDSTOPS

# Should show:
# x: open/TRIGGERED
# y: open/TRIGGERED
# z: open/TRIGGERED

# Test endstop by manually pressing and querying again
```

## Log Analysis Commands

### Essential Log Commands

```bash
# View last 100 lines
klipper_exec "tail -100 logs/klippy.log"

# Search for errors
klipper_exec "tail -500 logs/klippy.log | grep -i error"

# Search for warnings
klipper_exec "tail -500 logs/klippy.log | grep -i warn"

# Check MCU communication
klipper_exec "tail -500 logs/klippy.log | grep -i mcu"

# View startup sequence
klipper_exec "head -200 logs/klippy.log"

# Errors and warnings together
klipper_exec "tail -500 logs/klippy.log | grep -E 'error|warn|MCU'"
```

### Analyzing Print Failures

```bash
# Get timestamp range of last print
klipper_exec "grep 'START_PRINT\|END_PRINT\|CANCEL_PRINT' logs/klippy.log | tail -5"

# View logs during that time period
# (adjust tail number based on timestamps)
klipper_exec "tail -1000 logs/klippy.log | grep -A 5 -B 5 'error'"
```

## Configuration Syntax Errors

### Invalid Config

**Symptoms:**
- Klipper fails to start
- "Config error" in logs
- Web interface shows "disconnected"

**Causes:**
- Syntax error in printer.cfg
- Invalid section name
- Missing required parameter

**Solutions:**
```bash
# View config syntax check from logs
klipper_exec "grep -i 'config\|error' logs/klippy.log | tail -20"

# Validate config locally (if backed up):
# klipper-check-config ~/.cache/klipper/config/printer.cfg

# Restore from backup if needed:
klipper_sync_up ~/backups/klipper-YYYYMMDD-HHMMSS/printer.cfg config/
```

## Safety Reminders

- **Always backup before changes**: `scripts/backup_config.sh`
- **Test at safe heights**: Start with Z=50mm, not Z=0
- **Watch first layer**: Stay near printer during first layer after changes
- **Small increments**: Change one setting at a time
- **Read logs**: Check logs after every change
- **Have restore plan**: Keep known-good config backup ready
