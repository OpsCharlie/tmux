#!/bin/bash

REBOOT_FLAG="/var/run/reboot-required"
[ -e "$REBOOT_FLAG" ] && printf "%s" "⟳  ⡇ "

