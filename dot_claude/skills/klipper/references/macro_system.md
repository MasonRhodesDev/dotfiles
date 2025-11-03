# Macro System

Comprehensive documentation of the klipper-macros system used on the Ender 3 V2.

## Overview

The printer uses the klipper-macros git submodule with 20+ macro files providing advanced features and automation. All macros are located in `config/klipper-macros/`.

## Core Macro Files

### globals.cfg (20KB)

Central variable definitions and defaults for the entire macro system.

**Key Contents:**
- Variable declarations used by all other macros
- Default values for temperatures, speeds, and distances
- Feature flags and behavior settings
- Path configurations

**Important Variables (from _km_options in printer.cfg):**
- `load_length: 30` - Filament load distance (30mm)
- `start_purge: 30` - Purge amount on print start (30mm)
- `variable_file: ~/printer_data/variables.cfg` - Persistent variable storage
- `virtual_sdcard_path: ~/printer_ender3v2_data/gcodes` - G-code file location

**Note:** Always review globals.cfg before overriding variables in printer.cfg. Many settings have interdependencies.

### start_end.cfg

Handles print start and end sequences.

**Macros:**
- `START_PRINT` - Called by slicer at print start
  - Parameters: `EXTRUDER_TEMP`, `BED_TEMP`, optional `CHAMBER_TEMP`
  - Performs homing, bed leveling, heating, purging
  - Integrates with other macro systems

- `END_PRINT` - Called by slicer at print end
  - Parks toolhead
  - Turns off heaters
  - Disables steppers after cooldown
  - Presents finished print

**Integration:** These macros must match the start/end G-code in OrcaSlicer machine profile.

### pause_resume_cancel.cfg

Print control macros for pausing, resuming, and canceling prints.

**Macros:**
- `PAUSE` - Pause print, park toolhead, optionally retract filament
- `RESUME` - Resume print, restore position, prime nozzle
- `CANCEL_PRINT` - Cancel print, run end sequence, clear state

**Usage:** Called via web interface or physical controls during prints.

### filament.cfg

Filament loading, unloading, and changing operations.

**Macros:**
- `LOAD_FILAMENT` - Heat nozzle, load filament, purge
- `UNLOAD_FILAMENT` - Heat nozzle, retract filament
- `CHANGE_FILAMENT` - Unload then load new filament

**Parameters:** Uses `load_length` from globals.cfg (30mm default).

## Advanced Features

### bed_mesh_fast.cfg + optional/bed_mesh.cfg

Optimized bed leveling system.

**Features:**
- Fast adaptive mesh based on print area
- Profile management (save/load meshes)
- Automatic mesh before prints
- Manual mesh calibration

**Macros:**
- `BED_MESH_CALIBRATE` - Run bed leveling sequence
- `BED_MESH_PROFILE` - Manage saved mesh profiles

### bed_surface.cfg

Multiple bed surface offset management.

**Purpose:** Store and apply Z-offsets for different build surfaces (glass, PEI, textured, etc.).

**Macros:**
- `SET_SURFACE_OFFSET` - Apply offset for specific surface
- `SAVE_SURFACE_OFFSET` - Store new surface offset

**Use Case:** Quickly switch between build plates without re-leveling.

### layers.cfg

Layer-based operations and notifications.

**Features:**
- Track current layer during print
- Execute commands at specific layers
- Layer change notifications
- Progress tracking

**Integration:** Works with START_PRINT/END_PRINT to monitor print progress.

### heaters.cfg

Temperature management and presets.

**Features:**
- Temperature presets for common materials
- Preheat macros
- Temperature monitoring
- Cooldown sequences

**Menu Temperatures (from _km_options):**
- PLA: 200°C nozzle / 60°C bed
- ABS: 245°C nozzle / 110°C bed / 60°C chamber

### fans.cfg

Fan control and management.

**Features:**
- Part cooling fan control
- Fan speed profiles
- Automatic fan control based on layer time
- Minimum fan speed settings

### park.cfg

Toolhead parking positions.

**Macros:**
- `PARK` - Park toolhead at safe position
- `PARK_FRONT` - Park at front for easy access
- `PARK_CENTER` - Park at bed center
- `PARK_REAR` - Park at rear

**Usage:** Automatically called by PAUSE, CANCEL_PRINT, and other macros.

### velocity.cfg

Speed and acceleration profiles.

**Features:**
- Velocity limit management
- Acceleration profiles for different print phases
- Speed factor controls
- Dynamic speed adjustment

### kinematics.cfg

Motion system configuration and calibration.

**Features:**
- Input shaping configuration
- Resonance compensation
- Motion smoothing
- Acceleration/deceleration profiles

## Configuration Integration

### printer.cfg Structure

```
[include mainsail.cfg]
[include klipper-macros/*.cfg]

[gcode_macro _km_options]
# User overrides for klipper-macros defaults
variable_load_length: 30
variable_start_purge: 30
...
```

### Macro Dependencies

Many macros depend on each other:
- `START_PRINT` uses bed_mesh, heaters, park, and velocity macros
- `PAUSE` depends on park and filament macros
- Layer tracking requires START_PRINT integration

**Important:** When modifying macros, check globals.cfg for dependencies and required variables.

## User Customization

### Override Pattern

1. Check default value in `globals.cfg`
2. Override in printer.cfg using `_km_options` macro
3. Keep documentation of what was changed and why

**Example:**
```
[gcode_macro _km_options]
variable_load_length: 40  # Changed from 30mm for direct drive
```

### Adding Custom Macros

Place custom macros in printer.cfg or a separate include file, not in klipper-macros/ (which is a git submodule).

## Troubleshooting

### Common Macro Errors

**"Unknown command: START_PRINT"**
- Check that `[include klipper-macros/*.cfg]` is in printer.cfg
- Verify klipper-macros submodule is initialized

**"Variable not found"**
- Check that the variable is defined in globals.cfg
- Verify _km_options overrides use correct variable names

**"Macro recursion depth exceeded"**
- Check for circular macro calls
- Review macro dependencies

### Debugging Macros

```bash
# View macro definitions
klipper_read config/printer.cfg | grep -A 20 "\[gcode_macro"

# Check macro includes
klipper_read config/printer.cfg | grep "include.*macro"

# View specific macro file
klipper_read config/klipper-macros/start_end.cfg
```
