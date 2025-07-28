#!/bin/bash
# Run as service ~/.config/systemd/user/pw-loopback.service
## Sleep for a few seconds to allow components to initialize
sleep 5

## Run pw-loopback command
/usr/bin/pw-loopback -C alsa_input.pci-0000_0e_00.4.analog-stereo

