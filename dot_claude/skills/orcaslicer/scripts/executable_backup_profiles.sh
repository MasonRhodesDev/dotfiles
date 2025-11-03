#!/bin/bash
# Automated OrcaSlicer profile backup with timestamps

set -e

# Generate timestamp
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$HOME/backups/orcaslicer-$TIMESTAMP"

echo "Creating backup directory: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Backup all user profiles
if [ -d "$HOME/.config/OrcaSlicer/user/default" ]; then
    echo "Backing up user profiles..."
    cp -r "$HOME/.config/OrcaSlicer/user/default" "$BACKUP_DIR/"
else
    echo "Error: User profile directory not found"
    exit 1
fi

# Backup app settings
if [ -f "$HOME/.config/OrcaSlicer/OrcaSlicer.conf" ]; then
    echo "Backing up application settings..."
    cp "$HOME/.config/OrcaSlicer/OrcaSlicer.conf" "$BACKUP_DIR/"
fi

# Create backup summary
cat > "$BACKUP_DIR/backup_info.txt" <<EOF
OrcaSlicer Profile Backup
Created: $(date)
Source: ~/.config/OrcaSlicer/

Contents:
- default/machine/   - Machine profiles
- default/filament/  - Filament profiles
- default/process/   - Process profiles
- OrcaSlicer.conf    - Application settings

E3V2 Profiles Included:
$(find "$BACKUP_DIR/default" -name "*E3V2*" 2>/dev/null | sed 's|.*/||' || echo "None found")

To restore:
  cp -r "$BACKUP_DIR/default/"* ~/.config/OrcaSlicer/user/default/
EOF

# Count files by type
MACHINE_COUNT=$(find "$BACKUP_DIR/default/machine" -name "*.json" 2>/dev/null | wc -l)
FILAMENT_COUNT=$(find "$BACKUP_DIR/default/filament" -name "*.json" 2>/dev/null | wc -l)
PROCESS_COUNT=$(find "$BACKUP_DIR/default/process" -name "*.json" 2>/dev/null | wc -l)

echo ""
echo "Backup completed successfully!"
echo "Location: $BACKUP_DIR"
echo "Profiles backed up:"
echo "  - Machine:  $MACHINE_COUNT profiles"
echo "  - Filament: $FILAMENT_COUNT profiles"
echo "  - Process:  $PROCESS_COUNT profiles"
echo ""
echo "To restore this backup:"
echo "  cp -r \"$BACKUP_DIR/default/\"* ~/.config/OrcaSlicer/user/default/"
