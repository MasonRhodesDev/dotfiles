# Hardware Configuration

Detailed hardware specifications and calibration data for the Ender 3 V2.

## BLTouch Probe

- **Z-offset**: 2.0mm
- **X-offset**: -48mm
- **Y-offset**: +2mm
- **Sensor pin**: ^PB1
- **Control pin**: PB0

### Important Notes

- BLTouch offsets are critical - incorrect values can crash the nozzle into the bed
- Always test Z-offset adjustments at safe heights
- X/Y offsets determine probe position relative to nozzle
- The probe is 48mm to the left and 2mm forward of the nozzle

## Bed Mesh

- **Grid**: 4x4 probe points
- **Range**: (12,22) to (187,222)
- **Speed**: 120mm/s
- **Z-hop**: 5mm

### Mesh Configuration Details

The mesh covers the printable area while accounting for the BLTouch probe offset:
- Minimum probe position: X=12, Y=22
- Maximum probe position: X=187, Y=222
- 16 total probe points in a 4×4 grid
- Probing speed of 120mm/s with 5mm Z-hop between points

## Safe Z Home

- **Home position**: (165, 119) - bed center
- **Speed**: 50mm/s
- **Z-hop**: 10mm

### Homing Sequence

1. X and Y axes home first
2. Toolhead moves to (165, 119)
3. Z-axis homes using BLTouch probe at center position
4. 10mm Z-hop ensures clearance during homing moves

## Motion Limits

- **X-axis**: 0-235mm
- **Y-axis**: 0-232mm
- **Z-axis**: Standard Ender 3 V2 height (250mm)
- **Microsteps**: 16
- **Rotation distance**: 40mm

### Stepper Configuration

All axes use:
- 16 microsteps per full step
- 40mm rotation distance (standard for 20-tooth GT2 pulleys)
- Standard Ender 3 V2 stepper motor mapping
