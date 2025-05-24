#!/bin/bash

# Set up logging
exec 1> >(logger -s -t $(basename $0)) 2>&1

# Check if DISPLAY is set
if [ -z "$DISPLAY" ]; then
    echo "ERROR: DISPLAY environment variable not set"
    exit 1
fi

# Wait for audio system to be ready (adjust timeout as needed)
timeout=30
while ! pw-cli info >/dev/null 2>&1; do
    if [ "$timeout" -le 0 ]; then
        echo "ERROR: Audio system (PipeWire) not available after timeout"
        exit 1
    fi
    timeout=$((timeout - 1))
    sleep 1
done

# Start Carla
echo "Starting Carla..."
carla "/home/markf/.config/audio/main.carxp" > /dev/null 2>&1 &
CARLA_PID=$!

# Give Carla time to start
sleep 2

# Check if Carla is running
if ! kill -0 $CARLA_PID 2>/dev/null; then
    echo "ERROR: Carla failed to start"
    exit 1
fi

# Start qpwgraph
echo "Starting qpwgraph..."
nohup qpwgraph -a -x -m "/home/markf/.config/audio/pb1.qpwgraph" > /dev/null 2>&1 &
QPWGRAPH_PID=$!

# Check if qpwgraph started
sleep 2
if ! kill -0 $QPWGRAPH_PID 2>/dev/null; then
    echo "ERROR: qpwgraph failed to start"
    exit 1
fi

echo "Audio graph started successfully"
