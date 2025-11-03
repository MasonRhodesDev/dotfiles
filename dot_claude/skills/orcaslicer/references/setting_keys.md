# Common Setting Keys

Reference guide for frequently used OrcaSlicer setting keys across all profile types.

## Machine Profile Settings

### Build Volume

| Setting Key | Type | Description | Example |
|-------------|------|-------------|---------|
| `printable_area` | Array | Bed coordinates [[x1,y1],[x2,y2],...] | `[[0,0],[235,0],[235,232],[0,232]]` |
| `printable_height` | String | Maximum Z height in mm | `"250"` |
| `bed_exclude_area` | Array | Unprintable zones on bed | `[[10,10],[20,20]]` |

### Extruder Configuration

| Setting Key | Type | Description | Example |
|-------------|------|-------------|---------|
| `nozzle_diameter` | Array | Nozzle size in mm | `["0.4"]` |
| `nozzle_type` | String | Nozzle material/type | `"hardened_steel"` |
| `max_layer_height` | Array | Maximum layer thickness | `["0.28"]` |
| `min_layer_height` | Array | Minimum layer thickness | `["0.08"]` |

### Retraction

| Setting Key | Type | Description | Example |
|-------------|------|-------------|---------|
| `retraction_length` | Array | Retract distance in mm | `["1"]` |
| `retraction_speed` | Array | Retract speed in mm/s | `["40"]` |
| `deretraction_speed` | Array | Unretract speed in mm/s | `["40"]` |
| `retraction_minimum_travel` | Array | Min travel to trigger retract | `["2"]` |
| `retract_when_changing_layer` | Bool | Retract on layer change | `true` |
| `retract_before_wipe` | Array | Retract before wipe move | `["70%"]` |

### G-code

| Setting Key | Type | Description | Example |
|-------------|------|-------------|---------|
| `machine_start_gcode` | String | Start G-code script | `"G28 ; home\nG29 ; level"` |
| `machine_end_gcode` | String | End G-code script | `"G28 X0 Y0 ; home X/Y"` |
| `layer_change_gcode` | String | Per-layer G-code | `"; Layer [layer_num]"` |
| `time_lapse_gcode` | String | Time-lapse snapshot G-code | `"G0 X0 Y0"` |

### Print Host

| Setting Key | Type | Description | Example |
|-------------|------|-------------|---------|
| `print_host` | String | Octoprint/Moonraker address | `"192.168.1.XXX:7125"` |
| `printhost_authorization_type` | String | Auth method | `"key"` or `"password"` |
| `printhost_apikey` | String | API key for auth | `"1234567890ABCDEF"` |

### Firmware

| Setting Key | Type | Description | Example |
|-------------|------|-------------|---------|
| `gcode_flavor` | String | G-code dialect | `"klipper"` or `"marlin"` |
| `silent_mode` | Bool | Use silent mode | `false` |

## Filament Profile Settings

### Temperatures

| Setting Key | Type | Description | Example |
|-------------|------|-------------|---------|
| `nozzle_temperature` | Array | Extruder temp in °C | `["200"]` |
| `hot_plate_temp` | String | Bed temp in °C | `"60"` |
| `hot_plate_temp_initial_layer` | String | First layer bed temp | `"65"` |
| `chamber_temperature` | String | Enclosure temp in °C | `"0"` |
| `nozzle_temperature_initial_layer` | Array | First layer nozzle temp | `["210"]` |
| `nozzle_temperature_range_low` | Array | Min safe temp | `["180"]` |
| `nozzle_temperature_range_high` | Array | Max safe temp | `["230"]` |

### Flow Control

| Setting Key | Type | Description | Example |
|-------------|------|-------------|---------|
| `filament_flow_ratio` | Array | Extrusion multiplier | `["0.95"]` |
| `filament_max_volumetric_speed` | Array | Max flow in mm³/s | `["8"]` |
| `filament_diameter` | Array | Filament diameter in mm | `["1.75"]` |
| `extrusion_multiplier` | Array | Legacy flow ratio | `["1.0"]` |

### Cooling

| Setting Key | Type | Description | Example |
|-------------|------|-------------|---------|
| `fan_min_speed` | Array | Min fan speed % | `["20"]` |
| `fan_max_speed` | Array | Max fan speed % | `["100"]` |
| `fan_cooling_layer_time` | Array | Layer time threshold | `["60"]` |
| `slow_down_layer_time` | Array | Slowdown threshold | `["5"]` |
| `fan_below_layer_time` | Array | Full fan below time | `["10"]` |
| `disable_fan_first_layers` | Array | No fan for N layers | `["1"]` |

### Material Properties

| Setting Key | Type | Description | Example |
|-------------|------|-------------|---------|
| `filament_type` | Array | Material type | `["PLA"]` |
| `filament_density` | Array | Density in g/cm³ | `["1.24"]` |
| `filament_cost` | Array | Cost per kg | `["20"]` |
| `filament_colour` | Array | Color hex code | `["#FF0000"]` |

### Retraction Override

| Setting Key | Type | Description | Example |
|-------------|------|-------------|---------|
| `filament_retraction_length` | Array | Material-specific retract | `["0.8"]` |
| `filament_retraction_speed` | Array | Material-specific speed | `["35"]` |

### Material G-code

| Setting Key | Type | Description | Example |
|-------------|------|-------------|---------|
| `filament_start_gcode` | Array | Before print | `["; PLA start"]` |
| `filament_end_gcode` | Array | After print | `["; PLA end"]` |

## Process Profile Settings

### Layer Heights

| Setting Key | Type | Description | Example |
|-------------|------|-------------|---------|
| `layer_height` | String | Standard layer height | `"0.20"` |
| `initial_layer_height` | String | First layer height | `"0.2"` |
| `adaptive_layer_height` | Bool | Variable layer height | `false` |

### Perimeters/Walls

| Setting Key | Type | Description | Example |
|-------------|------|-------------|---------|
| `wall_loops` | String | Number of perimeters | `"3"` |
| `wall_thickness` | String | Total wall thickness | `"1.2"` |
| `top_shell_layers` | String | Top solid layers | `"4"` |
| `top_shell_thickness` | String | Top solid thickness | `"0.8"` |
| `bottom_shell_layers` | String | Bottom solid layers | `"3"` |
| `bottom_shell_thickness` | String | Bottom solid thickness | `"0.6"` |
| `ensure_vertical_shell_thickness` | Bool | Maintain shell thickness | `true` |

### Infill

| Setting Key | Type | Description | Example |
|-------------|------|-------------|---------|
| `sparse_infill_density` | String | Infill percentage | `"20%"` |
| `sparse_infill_pattern` | String | Infill pattern type | `"grid"` |
| `top_surface_pattern` | String | Top surface pattern | `"monotonic"` |
| `bottom_surface_pattern` | String | Bottom pattern | `"monotonic"` |
| `sparse_infill_line_width` | String | Infill line width | `"0.45"` |

**Common Infill Patterns:**
- `grid` - Standard grid (fast)
- `cubic` - 3D cube (isotropic strength)
- `gyroid` - Wavy pattern (flexible)
- `honeycomb` - Hexagonal (strong)
- `line` - Parallel lines (fastest)
- `concentric` - Concentric rings
- `triangles` - Triangular pattern

### Print Speeds

| Setting Key | Type | Description | Example |
|-------------|------|-------------|---------|
| `outer_wall_speed` | String | Outer perimeter speed | `"30"` |
| `inner_wall_speed` | String | Inner perimeter speed | `"60"` |
| `sparse_infill_speed` | String | Infill speed | `"80"` |
| `internal_solid_infill_speed` | String | Solid infill speed | `"60"` |
| `top_surface_speed` | String | Top surface speed | `"40"` |
| `travel_speed` | String | Non-print moves | `"150"` |
| `initial_layer_speed` | String | First layer speed | `"20"` |
| `bridge_speed` | String | Bridging speed | `"25"` |

**Speed Units**: mm/s

### Acceleration

| Setting Key | Type | Description | Example |
|-------------|------|-------------|---------|
| `default_acceleration` | String | General accel in mm/s² | `"1000"` |
| `outer_wall_acceleration` | String | Outer perimeter accel | `"500"` |
| `inner_wall_acceleration` | String | Inner perimeter accel | `"1000"` |
| `initial_layer_acceleration` | String | First layer accel | `"500"` |
| `travel_acceleration` | String | Travel move accel | `"2000"` |

### Support

| Setting Key | Type | Description | Example |
|-------------|------|-------------|---------|
| `enable_support` | Bool | Generate supports | `true` |
| `support_type` | String | Support style | `"normal"` or `"tree"` |
| `support_angle` | String | Overhang threshold | `"45"` |
| `support_on_build_plate_only` | Bool | No supports on model | `false` |
| `support_top_z_distance` | String | Top gap in mm | `"0.2"` |
| `support_bottom_z_distance` | String | Bottom gap in mm | `"0.2"` |
| `support_base_pattern_spacing` | String | Support XY distance | `"2.5"` |
| `support_interface_spacing` | String | Roof/floor spacing | `"0.2"` |
| `support_interface_pattern` | String | Interface pattern | `"rectilinear"` |

### Seam

| Setting Key | Type | Description | Example |
|-------------|------|-------------|---------|
| `seam_position` | String | Where seam appears | `"aligned"` |
| `seam_gap` | String | Seam gap control | `"10%"` |

**Seam Positions:**
- `aligned` - Aligned to single edge
- `back` - At back of print
- `random` - Random placement
- `nearest` - Nearest point

### Bridging

| Setting Key | Type | Description | Example |
|-------------|------|-------------|---------|
| `bridge_flow` | String | Bridge extrusion ratio | `"0.8"` |
| `bridge_speed` | String | Bridge speed in mm/s | `"25"` |
| `bridge_angle` | String | Bridge direction | `"0"` |

### Skirt/Brim

| Setting Key | Type | Description | Example |
|-------------|------|-------------|---------|
| `skirt_loops` | String | Number of skirt loops | `"1"` |
| `skirt_distance` | String | Skirt distance from part | `"3"` |
| `brim_width` | String | Brim width in mm | `"0"` |
| `brim_type` | String | Brim style | `"auto_brim"` |

### Raft

| Setting Key | Type | Description | Example |
|-------------|------|-------------|---------|
| `raft_layers` | String | Number of raft layers | `"0"` |
| `raft_contact_distance` | String | Gap between raft & part | `"0.1"` |

### Advanced

| Setting Key | Type | Description | Example |
|-------------|------|-------------|---------|
| `elefant_foot_compensation` | String | First layer compensation | `"0.15"` |
| `xy_hole_compensation` | String | Hole size compensation | `"0"` |
| `xy_contour_compensation` | String | Outer contour compensation | `"0"` |
| `arc_fitting` | Bool | Use arc commands (G2/G3) | `false` |

## Variable Substitution in G-code

OrcaSlicer supports variables in G-code strings:

### Temperature Variables

- `[nozzle_temperature]` - Target nozzle temp
- `[bed_temperature]` - Target bed temp
- `[chamber_temperature]` - Target chamber temp
- `[nozzle_temperature_initial_layer]` - First layer nozzle temp

### Position Variables

- `[layer_num]` - Current layer number (0-indexed)
- `[layer_z]` - Current Z height

### Timing Variables

- `[total_layer_count]` - Total layers in print
- `[print_time]` - Estimated print time

### File Variables

- `[input_filename]` - Source model filename
- `[input_filename_base]` - Filename without extension

### Usage Example

```gcode
; Layer [layer_num] of [total_layer_count]
; Z Height: [layer_z]mm
START_PRINT EXTRUDER_TEMP=[nozzle_temperature] BED_TEMP=[bed_temperature]
```

## Finding Setting Keys

To find setting keys not listed here:

1. **View JSON directly**:
```bash
cat ~/.config/OrcaSlicer/user/default/process/profile.json | jq .
```

2. **Compare profiles**:
```bash
diff <(jq -S . profile1.json) <(jq -S . profile2.json)
```

3. **OrcaSlicer GUI**: Settings visible in GUI correspond to JSON keys (usually same name with underscores)

4. **OrcaSlicer source code**: Reference implementation at github.com/SoftFever/OrcaSlicer
