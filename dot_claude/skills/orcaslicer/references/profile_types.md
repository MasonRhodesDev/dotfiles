# Profile Types

Comprehensive explanation of OrcaSlicer's three profile types and their inheritance system.

## Overview

OrcaSlicer uses three profile types that work together to define print settings:

1. **Machine Profiles** - Hardware characteristics
2. **Filament Profiles** - Material properties
3. **Process Profiles** - Print quality and speed

## Machine Profiles

Define printer hardware characteristics and physical capabilities.

### Key Settings

**Build Volume:**
- `printable_area` - Build plate dimensions (X/Y coordinates)
- `printable_height` - Maximum Z height
- `bed_exclude_area` - Unprintable zones

**Extruder Configuration:**
- `nozzle_diameter` - Nozzle size (typically 0.4mm)
- `nozzle_type` - Standard, hardened, etc.
- `extruder_offset` - Multi-extruder position offsets

**Retraction:**
- `retraction_length` - Filament retract distance
- `retraction_speed` - Retract/unretract speeds
- `retraction_minimum_travel` - Minimum move distance to trigger retract

**Start/End G-code:**
- `machine_start_gcode` - Commands run at print start
- `machine_end_gcode` - Commands run at print end
- `layer_change_gcode` - Commands run on layer changes

**Print Host:**
- `print_host` - Moonraker/Octoprint address (e.g., 192.168.1.XXX:7125)
- `printhost_authorization_type` - Authentication method

**Bed Leveling:**
- `z_offset` - Nozzle height offset
- Mesh leveling configuration

**Cooling:**
- Fan configuration and control

### Example Structure

```json
{
    "name": "[E3V2] Ender-3 V2",
    "version": "2.3.2.0",
    "inherits": "Creality Ender-3 V2 0.4 nozzle",
    "printable_area": [[0,0], [235,0], [235,232], [0,232]],
    "printable_height": "250",
    "retraction_length": ["1"],
    "print_host": "192.168.1.XXX:7125",
    "machine_start_gcode": "START_PRINT EXTRUDER_TEMP=[nozzle_temperature] BED_TEMP=[bed_temperature]"
}
```

## Filament Profiles

Define material-specific settings that vary by filament type.

### Key Settings

**Temperatures:**
- `nozzle_temperature` - Extruder temperature(s)
- `hot_plate_temp` - Bed temperature
- `hot_plate_temp_initial_layer` - First layer bed temp
- `chamber_temperature` - Enclosure temperature (if applicable)

**Flow Rates:**
- `filament_flow_ratio` - Extrusion multiplier (1.0 = 100%)
- `filament_max_volumetric_speed` - Maximum flow rate

**Cooling:**
- `fan_min_speed` - Minimum part cooling fan speed
- `fan_max_speed` - Maximum part cooling fan speed
- `fan_cooling_layer_time` - Layer time thresholds for fan control

**Retraction:**
- `filament_retraction_length` - Material-specific retract distance
- `filament_retraction_speed` - Material-specific retract speeds

**Material Properties:**
- `filament_type` - PLA, ABS, PETG, etc.
- `filament_density` - Material density for weight calculation
- `filament_cost` - Price per kg for cost estimation

**Material-Specific G-code:**
- `filament_start_gcode` - Commands before print
- `filament_end_gcode` - Commands after print

**Compatibility:**
- `compatible_printers` - Which printers work with this material

### Example Structure

```json
{
    "name": "[E3V2] PLA",
    "version": "2.3.2.0",
    "inherits": "Creality Generic PLA",
    "filament_type": "PLA",
    "nozzle_temperature": ["200"],
    "hot_plate_temp": "60",
    "hot_plate_temp_initial_layer": "60",
    "filament_flow_ratio": ["0.95"]
}
```

## Process Profiles

Define print quality and speed settings that determine how the print is sliced.

### Key Settings

**Layer Heights:**
- `layer_height` - Standard layer thickness
- `initial_layer_height` - First layer thickness
- `adaptive_layer_height` - Variable layer height settings

**Shells:**
- `wall_loops` - Number of perimeters/walls
- `top_shell_layers` - Solid layers on top
- `bottom_shell_layers` - Solid layers on bottom
- `wall_thickness` - Total perimeter thickness

**Infill:**
- `sparse_infill_density` - Infill percentage (0-100%)
- `sparse_infill_pattern` - Infill pattern (grid, cubic, gyroid, etc.)
- `sparse_infill_line_width` - Infill line thickness

**Print Speeds:**
- `outer_wall_speed` - Speed for outer perimeter
- `inner_wall_speed` - Speed for inner perimeters
- `sparse_infill_speed` - Speed for infill
- `top_surface_speed` - Speed for top solid layers
- `travel_speed` - Non-printing move speed
- `initial_layer_speed` - First layer speed

**Support:**
- `enable_support` - Support generation on/off
- `support_type` - Normal or tree support
- `support_angle` - Overhang angle threshold
- `support_interface_spacing` - Support roof density
- `support_top_z_distance` - Gap between support and part top
- `support_base_pattern_spacing` - Support XY distance from part

**Seam:**
- `seam_position` - Where layer seam is placed
- `seam_gap` - Seam alignment settings

**Bridging:**
- `bridge_flow` - Flow rate for bridges
- `bridge_speed` - Speed for bridging moves

**Acceleration/Jerk:**
- `default_acceleration` - General acceleration
- `outer_wall_acceleration` - Perimeter acceleration
- `initial_layer_acceleration` - First layer acceleration

### Example Structure

```json
{
    "name": "[E3V2] 0.20mm Structural",
    "version": "2.3.2.0",
    "inherits": "0.20mm Standard @Creality Ender3V2",
    "layer_height": "0.20",
    "sparse_infill_density": "35%",
    "top_shell_layers": "6",
    "bottom_shell_layers": "4",
    "support_top_z_distance": "0.3",
    "support_base_pattern_spacing": "0.5"
}
```

## Profile Inheritance

OrcaSlicer profiles support inheritance to avoid duplication.

### How Inheritance Works

1. **Parent Profile**: System or user profile providing base settings
2. **Child Profile**: Inherits all parent settings
3. **Overrides**: Child only stores settings that differ from parent

### Inheritance Chain

```
System Profile (read-only, factory defaults)
    ↓ inherits
User Profile (customizable, stores only differences)
```

### Example

**Parent Profile** (System): `Creality Generic PLA`
```json
{
    "nozzle_temperature": ["210"],
    "hot_plate_temp": "60",
    "filament_flow_ratio": ["1.0"]
}
```

**Child Profile** (User): `[E3V2] PLA`
```json
{
    "inherits": "Creality Generic PLA",
    "filament_flow_ratio": ["0.95"]  // Only stores this override
}
```

**Effective Settings** for `[E3V2] PLA`:
- `nozzle_temperature`: `["210"]` (from parent)
- `hot_plate_temp`: `"60"` (from parent)
- `filament_flow_ratio`: `["0.95"]` (overridden in child)

### Benefits of Inheritance

1. **Reduced duplication**: Don't repeat unchanged settings
2. **Easier updates**: Parent profile updates propagate automatically
3. **Clear customization**: Child profile shows only your changes
4. **Organized profiles**: Logical hierarchy of presets

### Creating Inherited Profiles

```bash
# Start with existing profile as template
cd ~/.config/OrcaSlicer/user/default/process/
cp "[E3V2] 0.20mm Structural.json" "[E3V2] 0.20mm Custom.json"

# Edit new profile
vim "[E3V2] 0.20mm Custom.json"

# Change:
# 1. "name" field
# 2. "inherits" field (to specify parent)
# 3. Add/modify only settings that differ from parent
```

## System vs User Profiles

### System Profiles

**Location**: `~/.config/OrcaSlicer/system/`

**Characteristics:**
- Read-only (managed by OrcaSlicer)
- Factory defaults for specific printers
- Updated when OrcaSlicer updates
- Cannot be modified directly

**Purpose**: Provide base configurations for standard printers and materials

### User Profiles

**Location**: `~/.config/OrcaSlicer/user/default/`

**Characteristics:**
- Read-write (user-managed)
- Custom configurations
- Persist across OrcaSlicer updates
- Can inherit from system or other user profiles

**Purpose**: Store customizations and printer-specific tuning

## File Format

All profiles are JSON files with:

### Metadata Fields

```json
{
    "name": "Profile Name",
    "version": "2.3.2.0",  // OrcaSlicer version
    "inherits": "Parent Profile Name",  // Optional
    "type": "machine|filament|process",
    // ... settings ...
}
```

### Comments

OrcaSlicer preserves `//` style comments in JSON files (non-standard but supported).

```json
{
    "layer_height": "0.20",  // Layer thickness in mm
    "sparse_infill_density": "20%"  // 20% infill
}
```

### Validation

Always validate JSON after manual editing:

```bash
jq . profile.json > /dev/null
```

If valid, no output. If invalid, error message shown.
