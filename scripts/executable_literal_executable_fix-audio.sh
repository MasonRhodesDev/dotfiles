#!/bin/bash

# Fixes buzzing sound on xps 15 9500

# create alsa-base.conf if it doesn't exist
if [ ! -f /etc/modprobe.d/alsa-base.conf ]; then
    sudo touch /etc/modprobe.d/alsa-base.conf
fi

# add options snd-hda-intel power_save=0 power_save_controller=N to alsa-base.conf if it doesn't already have it
if ! grep -q "options snd-hda-intel power_save=0 power_save_controller=N" /etc/modprobe.d/alsa-base.conf; then
    echo "options snd-hda-intel power_save=0 power_save_controller=N" | sudo tee -a /etc/modprobe.d/alsa-base.conf
fi
