#!/bin/bash

# Master Gain Control Script - Fast Version
# Easy control of PipeWire LADSPA gain plugin

# Cache file for node ID
CACHE_FILE="/tmp/master_gain_node_id"

# Pre-calculated dB multipliers (avoids bc calls)
# +1dB = 10^(1/20) ≈ 1.122
# -1dB = 10^(-1/20) ≈ 0.891  
# +3dB = 10^(3/20) ≈ 1.414
# -3dB = 10^(-3/20) ≈ 0.707
DB_PLUS_1="1.122"
DB_MINUS_1="0.891"
DB_PLUS_3="1.414" 
DB_MINUS_3="0.707"
DB_PLUS_6="2.0"
DB_MINUS_6="0.5"
DB_PLUS_12="4.0"
DB_MINUS_12="0.25"

# Find node ID (with permanent caching)
get_node_id() {
    # Check if cache exists and read it
    if [ -f "$CACHE_FILE" ]; then
        local cached_id=$(cat "$CACHE_FILE")
        # Verify the cached node ID is still valid by checking output
        local output=$(pw-cli i "$cached_id" 2>&1)
        if [[ "$output" != *"Error:"* ]] && [[ "$output" != *"unknown"* ]] && [[ -n "$output" ]]; then
            echo "$cached_id"
            return
        else
            # Cached ID is invalid, remove cache and continue
            rm -f "$CACHE_FILE"
        fi
    fi
    
    # Find node ID and cache it
    local node_id=$(pw-dump | jq -r '.[] | select(.info.props."node.description" == "Master Gain Input") | .id' 2>/dev/null)
    
    if [ -n "$node_id" ] && [ "$node_id" != "null" ]; then
        echo "$node_id" > "$CACHE_FILE"
        echo "$node_id"
    else
        echo ""
    fi
}

NODE_ID=$(get_node_id)

if [ -z "$NODE_ID" ]; then
    echo "Error: Master Gain Input node not found!"
    exit 1
fi

# Fast gain retrieval using pw-cli directly
get_current_gain() {
    local node_id="$NODE_ID"
    
    # If node_id is invalid, get a fresh one
    local output=$(pw-cli i "$node_id" 2>&1)
    if [[ "$output" == *"Error:"* ]] || [[ "$output" == *"unknown"* ]] || [[ -z "$output" ]]; then
        node_id=$(get_node_id)
        if [ -z "$node_id" ]; then
            echo "1.0"  # Fallback
            return
        fi
    fi
    
    # Use pw-cli to get the Props parameter and extract the gain value
    local gain=$(pw-cli e "$node_id" Props 2>/dev/null | grep -A1 '"gain_plugin:Gain"' | tail -n1 | grep -o '[0-9.]*' | head -1)
    echo "${gain:-1.0}"
}

# Fast gain setting
set_gain() {
    local new_gain=$1
    local node_id="$NODE_ID"
    
    # If node_id is invalid, get a fresh one
    local output=$(pw-cli i "$node_id" 2>&1)
    if [[ "$output" == *"Error:"* ]] || [[ "$output" == *"unknown"* ]] || [[ -z "$output" ]]; then
        node_id=$(get_node_id)
        if [ -z "$node_id" ]; then
            echo "Error: Cannot find Master Gain Input node" >&2
            return 1
        fi
    fi
    
    pw-cli s "$node_id" Props "{\"params\": [\"gain_plugin:Gain\", $new_gain]}" >/dev/null 2>&1
}

# Fast current gain display (for waybar)
show_current_fast() {
    get_current_gain
}

# Shell-based floating point multiplication (avoids bc)
multiply_gain() {
    local current=$1
    local multiplier=$2
    # Use awk for floating point math - faster than bc
    awk "BEGIN {printf \"%.6f\", $current * $multiplier}"
}

# Main script logic
case $1 in
    current)
        echo "Current gain: $(get_current_gain)"
        ;;
    current-fast|fast)
        # Just output the number for waybar (fastest possible)
        show_current_fast
        ;;
    debug)
        echo "Found Master Gain Input node ID: $NODE_ID"
        echo "Cache file: $CACHE_FILE"
        ;;
    +1)
        current=$(get_current_gain)
        if (( $(awk "BEGIN {print ($current <= 0.001)}") )); then
            set_gain "$DB_PLUS_1"
        else
            new_gain=$(multiply_gain "$current" "$DB_PLUS_1")
            set_gain "$new_gain"
        fi
        ;;
    -1)
        current=$(get_current_gain)
        if (( $(awk "BEGIN {print ($current <= 0.001)}") )); then
            echo "Cannot reduce: at silence" >&2
        else
            new_gain=$(multiply_gain "$current" "$DB_MINUS_1")
            set_gain "$new_gain"
        fi
        ;;
    +3)
        current=$(get_current_gain)
        if (( $(awk "BEGIN {print ($current <= 0.001)}") )); then
            set_gain "$DB_PLUS_3"
        else
            new_gain=$(multiply_gain "$current" "$DB_PLUS_3")
            set_gain "$new_gain"
        fi
        ;;
    -3)
        current=$(get_current_gain)
        if (( $(awk "BEGIN {print ($current <= 0.001)}") )); then
            echo "Cannot reduce: at silence" >&2
        else
            new_gain=$(multiply_gain "$current" "$DB_MINUS_3")
            set_gain "$new_gain"
        fi
        ;;
    +6)
        current=$(get_current_gain)
        if (( $(awk "BEGIN {print ($current <= 0.001)}") )); then
            set_gain "$DB_PLUS_6"
        else
            new_gain=$(multiply_gain "$current" "$DB_PLUS_6")
            set_gain "$new_gain"
        fi
        ;;
    -6)
        current=$(get_current_gain)
        if (( $(awk "BEGIN {print ($current <= 0.001)}") )); then
            echo "Cannot reduce: at silence" >&2
        else
            new_gain=$(multiply_gain "$current" "$DB_MINUS_6")
            set_gain "$new_gain"
        fi
        ;;
    +12)
        current=$(get_current_gain)
        if (( $(awk "BEGIN {print ($current <= 0.001)}") )); then
            set_gain "$DB_PLUS_12"
        else
            new_gain=$(multiply_gain "$current" "$DB_PLUS_12")
            set_gain "$new_gain"
        fi
        ;;
    -12)
        current=$(get_current_gain)
        if (( $(awk "BEGIN {print ($current <= 0.001)}") )); then
            echo "Cannot reduce: at silence" >&2
        else
            new_gain=$(multiply_gain "$current" "$DB_MINUS_12")
            set_gain "$new_gain"
        fi
        ;;
    reset)
        set_gain "1.0"
        ;;
    clear-cache)
        rm -f "$CACHE_FILE"
        echo "Cache cleared"
        ;;
    interactive)
        echo "Interactive mode disabled in fast version"
        echo "Use the original script for interactive mode"
        ;;
    -h|--help)
        echo "Master Gain Control (Fast Version)"
        echo "Usage: $0 [option]"
        echo ""
        echo "Options:"
        echo "  current          Show current gain"
        echo "  current-fast     Show current gain (fast, for waybar)"
        echo "  +1, +3, +6, +12  Boost current gain by X dB"
        echo "  -1, -3, -6, -12  Cut current gain by X dB"
        echo "  reset            Reset to unity gain (1.0)"
        echo "  clear-cache      Clear node ID cache"
        echo "  debug            Show node ID and cache info"
        ;;
    "")
        show_current_fast
        ;;
    *)
        # Check if it's a number
        if [[ $1 =~ ^[0-9]+\.?[0-9]*$ ]]; then
            set_gain "$1"
        else
            echo "Invalid option: $1" >&2
            exit 1
        fi
        ;;
esac 