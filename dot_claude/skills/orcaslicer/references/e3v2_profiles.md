# E3V2 Profiles

Complete documentation of the custom [E3V2] tagged profiles for the Ender 3 V2.

## Overview

Three custom profiles are tagged with [E3V2] for the Ender 3 V2 printer:

1. **[E3V2] Ender-3 V2** - Machine profile (hardware configuration)
2. **[E3V2] PLA** - Filament profile (material settings)
3. **[E3V2] 0.20mm Structural** - Process profile (print quality)

## [E3V2] Ender-3 V2 (Machine)

**Location**: `~/.config/OrcaSlicer/user/default/machine/[E3V2] Ender-3 V2.json`

### Inheritance

Inherits from: `Creality Ender-3 V2 0.4 nozzle` (system profile)

### Key Customizations

**Print Host Integration:**
```json
{
    "print_host": "192.168.1.23:7125",
    "printhost_authorization_type": "key"
}
```

- Configured for Moonraker/Klipper integration
- IP address should match printer at `192.168.1.216`
- Port 7125 is standard Moonraker API port

**Build Volume:**
```json
{
    "printable_area": [[0,0], [235,0], [235,232], [0,232]],
    "printable_height": "250"
}
```

- X: 235mm
- Y: 232mm
- Z: 250mm
- Standard Ender 3 V2 build volume

**Retraction:**
```json
{
    "retraction_length": ["1"]
}
```

- 1mm retraction (typical for Klipper with pressure advance)
- Lower than stock firmware due to Klipper's linear advance

### Start G-code

The machine profile includes custom start G-code that calls Klipper macros:

```gcode
START_PRINT EXTRUDER_TEMP=[nozzle_temperature] BED_TEMP=[bed_temperature]
```

**Important**: This macro must exist in Klipper config at `printer@192.168.1.216:~/printer_ender3v2_data/config/`

The START_PRINT macro typically handles:
- Homing (G28)
- Bed mesh leveling (BED_MESH_CALIBRATE)
- Heating to target temperatures
- Purge line
- Final positioning

### End G-code

```gcode
END_PRINT
```

The END_PRINT macro typically handles:
- Toolhead parking
- Heater shutdown
- Stepper disable
- Part presentation

## [E3V2] PLA (Filament)

**Location**: `~/.config/OrcaSlicer/user/default/filament/[E3V2] PLA.json`

### Inheritance

Inherits from: `Creality Generic PLA` (system profile)

### Key Customizations

**Flow Ratio:**
```json
{
    "filament_flow_ratio": ["0.95"]
}
```

- 95% flow rate (5% reduction from default)
- Tuned specifically for this printer's extrusion characteristics
- Reduces over-extrusion and improves dimensional accuracy

**Rationale**: Each printer's actual flow can vary due to:
- Nozzle size variance
- Extruder calibration
- Filament diameter tolerances
- Hotend heat characteristics

**Temperatures:**
```json
{
    "nozzle_temperature": ["200"],  // From parent
    "hot_plate_temp": "60",         // From parent
    "hot_plate_temp_initial_layer": "60"  // From parent
}
```

- Standard PLA temperatures
- 200°C nozzle
- 60°C bed (first layer and subsequent layers)

### When to Adjust Flow

**Signs of over-extrusion (reduce flow):**
- Dimensional inaccuracy (parts too large)
- Rough top surfaces
- Bulging layers
- Difficult to remove supports

**Signs of under-extrusion (increase flow):**
- Gaps in solid layers
- Weak layer adhesion
- Thin walls
- Incomplete infill

**Tuning Process:**
1. Print calibration cube
2. Measure dimensions with calipers
3. Adjust flow in 0.02-0.05 increments
4. Re-test until dimensions accurate

## [E3V2] 0.20mm Structural (Process)

**Location**: `~/.config/OrcaSlicer/user/default/process/[E3V2] 0.20mm Structural.json`

### Inheritance

Inherits from: `0.20mm Standard @Creality Ender3V2` (system profile)

### Purpose

Optimized for structural parts requiring higher strength than standard settings. Trade-offs:
- **Increased strength**: More top layers and infill
- **Longer print time**: More material to print
- **Higher material cost**: More filament used

### Key Customizations

**Layer Height:**
```json
{
    "layer_height": "0.20"
}
```

- 0.20mm layers (from parent)
- Balanced between speed and quality
- 70% of first layer height recommended

**Infill:**
```json
{
    "sparse_infill_density": "35%"
}
```

- 35% infill (increased from standard 20%)
- 75% stronger than 20% infill
- Good balance of strength vs print time

**Top Shell:**
```json
{
    "top_shell_layers": "6"
}
```

- 6 top solid layers (increased from standard 4)
- Provides 1.2mm solid top (6 × 0.20mm)
- Ensures completely solid top surface with no pillowing

**Bottom Shell:**
```json
{
    "bottom_shell_layers": "4"
}
```

- 4 bottom solid layers (standard)
- Provides 0.8mm solid bottom
- Adequate for bed adhesion and structural integrity

**Support Settings:**
```json
{
    "support_top_z_distance": "0.3",
    "support_base_pattern_spacing": "0.5"
}
```

- 0.3mm Z-gap between support and part (1.5 layers)
- 0.5mm XY-distance from part
- Easier support removal while maintaining quality

### Effective Settings Breakdown

| Setting | Value | Effect |
|---------|-------|--------|
| Layer Height | 0.20mm | Balanced quality/speed |
| Infill | 35% | High strength |
| Top Layers | 6 (1.2mm) | Solid top surface |
| Bottom Layers | 4 (0.8mm) | Good bed adhesion |
| Support Z-Gap | 0.3mm | Easy removal |
| Support XY-Gap | 0.5mm | Clean part surfaces |

### Comparison to Standard Profile

| Setting | Standard | Structural | Difference |
|---------|----------|------------|------------|
| Infill | 20% | 35% | +75% material |
| Top Layers | 4 | 6 | +50% thickness |
| Print Time | 1.0× | ~1.3× | +30% slower |
| Strength | 1.0× | ~1.5× | +50% stronger |

### When to Use

**Use Structural Profile For:**
- Functional parts under stress
- Parts requiring rigidity
- Items that will be handled frequently
- Mechanical components (brackets, mounts, etc.)
- Prototypes that need real-world testing

**Use Standard Profile For:**
- Display models
- Non-functional parts
- Rapid prototyping
- Parts where weight matters
- Cost-sensitive prints

### Creating Variants

To create specialized variants based on this profile:

```bash
cd ~/.config/OrcaSlicer/user/default/process/

# High-speed variant (reduce quality, increase speed)
cp "[E3V2] 0.20mm Structural.json" "[E3V2] 0.20mm Fast.json"
# Modify: reduce infill to 20%, reduce top_shell_layers to 4, increase speeds

# Maximum strength variant (increase quality, reduce speed)
cp "[E3V2] 0.20mm Structural.json" "[E3V2] 0.20mm Maximum.json"
# Modify: increase infill to 50%, increase top_shell_layers to 8, reduce speeds

# Detail variant (smaller layer height)
cp "[E3V2] 0.20mm Structural.json" "[E3V2] 0.12mm Detail.json"
# Modify: layer_height to 0.12, adjust top/bottom layer counts proportionally
```

## System E3V2 Profiles (Factory Defaults)

For reference, the system directory contains factory Ender 3 V2 profiles.

### System Machine Profiles

**Location**: `~/.config/OrcaSlicer/system/Creality/machine/`

1. **Creality Ender-3 V2 0.4 nozzle.json** - Full machine profile with 0.4mm nozzle
2. **Creality Ender-3 V2.json** - Base machine model

These are read-only and serve as inheritance parents for user profiles.

### System Process Profiles

**Location**: `~/.config/OrcaSlicer/system/Creality/process/`

Four quality presets:

| Profile | Layer Height | Use Case | Speed |
|---------|-------------|----------|-------|
| 0.12mm Fine | 0.12mm | High detail, slow | ~50% slower |
| 0.15mm Optimal | 0.15mm | Balanced quality | ~20% slower |
| 0.20mm Standard | 0.20mm | General purpose | Baseline |
| 0.24mm Draft | 0.24mm | Fast prototyping | ~30% faster |

The [E3V2] Structural profile inherits from "0.20mm Standard".

### Ender 3 V2 Neo

OrcaSlicer also includes profiles for the Ender 3 V2 Neo (newer model with minor differences):
- Neo has different motherboard
- Slightly different default settings
- Separate profile set to avoid conflicts

These are **not** used for the standard V2.

## Profile Interaction Example

When slicing with [E3V2] profiles selected:

```
Machine: [E3V2] Ender-3 V2
    └─ Provides: Build volume, retraction, start/end G-code, Klipper integration
    └─ Inherits: Creality Ender-3 V2 0.4 nozzle (system)

Filament: [E3V2] PLA
    └─ Provides: Temperatures (200°C/60°C), flow ratio (0.95)
    └─ Inherits: Creality Generic PLA (system)

Process: [E3V2] 0.20mm Structural
    └─ Provides: Layer height (0.20mm), infill (35%), top layers (6)
    └─ Inherits: 0.20mm Standard @Creality Ender3V2 (system)
```

The combination of these three profiles defines all settings for the print.

## Maintenance and Updates

### When OrcaSlicer Updates

- System profiles may be updated with new defaults
- User profiles remain unchanged
- Inherited settings automatically pick up system profile changes
- Overridden settings stay as configured

### Backing Up Profiles

Always backup before major changes:

```bash
scripts/backup_profiles.sh
```

Or manually:

```bash
cp -r ~/.config/OrcaSlicer/user/default ~/backups/orcaslicer-$(date +%Y%m%d-%H%M%S)
```

### Version Control

Consider tracking profiles in git:

```bash
cd ~/.config/OrcaSlicer/user/default
git init
git add machine/ filament/ process/
git commit -m "Initial E3V2 profiles"
```

This allows reverting changes and tracking modifications over time.
