#!/bin/bash
if [ "$1" = "on" ]; then
    echo "Enabling gaming mode..."
    echo 2147483642 | sudo tee /proc/sys/vm/max_map_count
    echo "Gaming mode enabled"
elif [ "$1" = "off" ]; then
    echo "Disabling gaming mode..."
    echo 65530 | sudo tee /proc/sys/vm/max_map_count
    echo "Gaming mode disabled"
else
    echo "Usage: $0 [on|off]"
fi
