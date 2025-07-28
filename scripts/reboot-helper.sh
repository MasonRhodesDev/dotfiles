#!/bin/bash

# NAME: grub-menu.sh
# PATH: $HOME/bin
# DESC: Written for AU Q&A: https://askubuntu.com/q/1019213/307523
# DATE: Apr 5, 2018. Modified: May 7, 2018.

# Updated to act as a dual-boot utility.

# flags
# -y: reboot after setting default boot entry
# -s {searchterm}: search for a specific entry and set it as default
# --search {searchterm}: search for a specific entry and set it as default
# --user {username}: to set in the sudoers file the username to run the script

# Parse command-line arguments
# Parse command-line arguments
args=()
while [ "$1" != "" ]; do
    case $1 in
        -y )
            args+=("$1")
            REBOOT="y"
            ;;
        -s | --search )
            args+=("$1")
            shift
            args+=("$1")
            SEARCHTERM="$1"  # Store the SEARCHTERM separately
            ;;
        --user )
            shift
            ORIGINAL_USER="$1"
            ;;
        * )
            args+=("$1")
            ;;
    esac
    shift
done

# Get current user if not already set
if [ -z "$ORIGINAL_USER" ]; then
    ORIGINAL_USER=$(id -un)
fi

# If not running with sudo, re-run script with sudo
if [ "$EUID" -ne 0 ]; then
    # Re-run script with sudo, passing all original arguments and the original user
    sudo --preserve-env=ORIGINAL_USER "$0" "${args[@]}" --user "$ORIGINAL_USER"
    exit $?
fi

# Detect script path
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

# Define sudoers entry
SUDOERS_ENTRY="$ORIGINAL_USER ALL=(ALL) NOPASSWD: $SCRIPT_PATH"

# filename no extension
FILENAME=$(basename "$SCRIPT_PATH")
FILENAME_NOEXT="${FILENAME%.*}"

# Check if the entry already exists and user is not root
if ! sudo grep -qFx "$SUDOERS_ENTRY" /etc/sudoers.d/"$FILENAME_NOEXT" && [ "$ORIGINAL_USER" != "root" ]; then
    # make sure the script is only writeable by root
    sudo chown root:root "$SCRIPT_PATH"
    # exutable by anyone
    sudo chmod 755 "$SCRIPT_PATH"
        
    # create file in /etc/sudoers.d/ to avoid syntax error
    echo "$SUDOERS_ENTRY" | sudo tee /etc/sudoers.d/$(basename "$FILENAME_NOEXT") >/dev/null
    # set correct permissions
    sudo chmod 044 /etc/sudoers.d/$(basename "$FILENAME_NOEXT")
    sudo chown root:root /etc/sudoers.d/$(basename "$FILENAME_NOEXT")
fi


# $TERM variable may be missing when called via desktop shortcut
CurrentTERM=$(env | grep TERM)
if [[ $CurrentTERM == "" ]] ; then
    notify-send --urgency=critical "$0 cannot be run from GUI without TERM environment variable."
    exit 1
fi

AllMenusArr=()      # All menu options.
# Default for hide duplicate and triplicate options with (upstart) and (recovery mode)?
HideUpstartRecovery=false
if [[ $1 == short ]] ; then
    HideUpstartRecovery=true    # override default with first passed parameter "short"
elif [[ $1 == long ]] ; then
    HideUpstartRecovery=false   # override default with first passed parameter "long"
fi
SkippedMenuEntry=false  # Don't change this value, automatically maintained
InSubMenu=false     # Within a line beginning with `submenu`?
InMenuEntry=false   # Within a line beginning with `menuentry` and ending in `{`?
NextMenuEntryNo=0   # Next grub internal menu entry number to assign
# Major / Minor internal grub submenu numbers, ie `1>0`, `1>1`, `1>2`, etc.
ThisSubMenuMajorNo=0
NextSubMenuMinorNo=0
CurrTag=""          # Current grub internal menu number, zero based
CurrText=""         # Current grub menu option text, ie "Ubuntu", "Windows...", etc.
SubMenuList=""      # Only supports 10 submenus! Numbered 0 to 9. Future use.

while read -r line; do
    # Example: "           }"
    BlackLine="${line//[[:blank:]]/}" # Remove all whitespace
    if [[ $BlackLine == "}" ]] ; then
        # Add menu option in buffer
        if [[ $SkippedMenuEntry == true ]] ; then
            NextSubMenuMinorNo=$(( $NextSubMenuMinorNo + 1 ))
            SkippedMenuEntry=false
            continue
        fi
        if [[ $InMenuEntry == true ]] ; then
            InMenuEntry=false
            if [[ $InSubMenu == true ]] ; then
                NextSubMenuMinorNo=$(( $NextSubMenuMinorNo + 1 ))
            else
                NextMenuEntryNo=$(( $NextMenuEntryNo + 1 ))
            fi
        elif [[ $InSubMenu == true ]] ; then
            InSubMenu=false
            NextMenuEntryNo=$(( $NextMenuEntryNo + 1 ))
        else
            continue # Future error message?
        fi
        # Set maximum CurrText size to 68 characters.
        CurrText="${CurrText:0:67}"
        AllMenusArr+=($CurrTag "$CurrText")
    fi

    # Example: "menuentry 'Ubuntu' --class ubuntu --class gnu-linux --class gnu" ...
    #          "submenu 'Advanced options for Ubuntu' $menuentry_id_option" ...
    if [[ $line == submenu* ]] ; then
        # line starts with `submenu`
        InSubMenu=true
        ThisSubMenuMajorNo=$NextMenuEntryNo
        NextSubMenuMinorNo=0
        SubMenuList=$SubMenuList$ThisSubMenuMajorNo
        CurrTag=$NextMenuEntryNo
        CurrText="${line#*\'}"
        CurrText="${CurrText%%\'*}"
        AllMenusArr+=($CurrTag "$CurrText") # ie "1 Advanced options for Ubuntu"

    elif [[ $line == menuentry* ]] && [[ $line == *"{"* ]] ; then
        # line starts with `menuentry` and ends with `{`
        if [[ $HideUpstartRecovery == true ]] ; then
            if [[ $line == *"(upstart)"* ]] || [[ $line == *"(recovery mode)"* ]] ; then
                SkippedMenuEntry=true
                continue
            fi
        fi
        InMenuEntry=true
        if [[ $InSubMenu == true ]] ; then
            : # In a submenu, increment minor instead of major which is "sticky" now.
            CurrTag=$ThisSubMenuMajorNo">"$NextSubMenuMinorNo
        else
            CurrTag=$NextMenuEntryNo
        fi
        CurrText="${line#*\'}"
        CurrText="${CurrText%%\'*}"

    else
        continue    # Other stuff - Ignore it.
    fi

done < /boot/grub/grub.cfg

LongVersion=$(grub-install --version)
ShortVersion=$(echo "${LongVersion:20}")
DefaultItem=$(sudo cat /boot/grub/grubenv | grep saved_entry= | awk -F= '{print $2}')

echo "All menu entries:"
for (( i=0; i < ${#AllMenusArr[@]}; i=i+2 )) ; do
    if [[ ${AllMenusArr[i]} == $DefaultItem ]] ; then
        printf "\033[1;31m%-5s  --  %s\033[0m\n" "${AllMenusArr[i]}" "${AllMenusArr[i+1]}"
    else
        printf "%-5s  --  %s\n" "${AllMenusArr[i]}" "${AllMenusArr[i+1]}"
    fi

    # if search term is defined, set default boot entry to found entry
    if [ -n "${SEARCHTERM}" ] ; then
        if [[ ${AllMenusArr[i+1]} == *"$SEARCHTERM"* ]] ; then
            echo "Found: ${AllMenusArr[i+1]}"
            # Set default boot entry to found entry
            sudo grub-set-default ${AllMenusArr[i]}
            echo "Default boot entry set to: ${AllMenusArr[i+1]}"

            # Reboot if requested startswith "y"
            if [ -n "${REBOOT}" ] & [ "${REBOOT}" == "y" ] ; then
                echo "Rebooting..."
                sudo reboot
            fi
            break
        fi
    fi
done

