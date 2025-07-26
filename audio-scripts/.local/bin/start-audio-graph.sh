#!/bin/bash

# Set up logging
exec 1> >(logger -s -t $(basename $0)) 2>&1

# Get the current hostname
HOSTNAME=$(hostname)
echo "Running on hostname: $HOSTNAME"

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

# Function to check if a process is running
is_running() {
    pgrep -f "$1" >/dev/null
    return $?
}

# Define hostname-specific configuration paths
CARLA_CONFIG="/home/markf/.config/audio/main-${HOSTNAME}.carxp"
QPWGRAPH_CONFIG="/home/markf/.config/audio/pb-${HOSTNAME}.qpwgraph"

# Check if configuration files exist
if [ ! -f "$CARLA_CONFIG" ]; then
    echo "ERROR: Carla configuration file not found: $CARLA_CONFIG"
    exit 1
fi

if [ ! -f "$QPWGRAPH_CONFIG" ]; then
    echo "ERROR: qpwgraph configuration file not found: $QPWGRAPH_CONFIG"
    exit 1
fi

# Start Carla if not already running
if ! is_running "carla.*main-${HOSTNAME}.carxp"; then
    echo "Starting Carla with config: $CARLA_CONFIG"
    carla "$CARLA_CONFIG" > /dev/null 2>&1 &
    CARLA_PID=$!

    # Give Carla time to start
    sleep 2

    # Check if Carla started successfully
    if ! kill -0 $CARLA_PID 2>/dev/null; then
        echo "ERROR: Carla failed to start"
        exit 1
    fi
else
    echo "Carla is already running"
fi

# Start qpwgraph if not already running
if ! is_running "qpwgraph"; then
    echo "Starting qpwgraph with config: $QPWGRAPH_CONFIG"
    nohup qpwgraph -a -x -m "$QPWGRAPH_CONFIG" > /dev/null 2>&1 &
    QPWGRAPH_PID=$!

    # Check if qpwgraph started
    sleep 2
    if ! kill -0 $QPWGRAPH_PID 2>/dev/null; then
        echo "ERROR: qpwgraph failed to start"
        exit 1
    fi
else
    echo "qpwgraph is already running"
fi

echo "Audio graph setup completed successfully"
