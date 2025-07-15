#!/bin/bash

# Master Gain Control Script
# Easy control of PipeWire LADSPA gain plugin

# Find the Master Gain Input node dynamically
NODE_ID=$(pw-dump | jq -r '.[] | select(.info.props."node.description" == "Master Gain Input") | .id')

if [ -z "$NODE_ID" ]; then
    echo "Error: Master Gain Input node not found!"
    echo "Make sure your PipeWire filter-chain is loaded."
    exit 1
fi

# Debug info (optional)
if [ "$1" = "debug" ]; then
    echo "Found Master Gain Input node ID: $NODE_ID"
fi

get_current_gain() {
    pw-dump | jq -r --arg node_id "$NODE_ID" '.[] | select(.id == ($node_id | tonumber)) | .info.params.Props[1].params[1]'
}

CURRENT_GAIN=$(get_current_gain)

show_current() {
    local current_gain=$(get_current_gain)
    if (( $(echo "$current_gain <= 0.001" | bc -l) )); then
        echo "Current gain: $current_gain (silence)"
    else
        echo "Current gain: $current_gain ($(echo "20 * l($current_gain)/l(10)" | bc -l | xargs printf "%.1f")dB)"
    fi
}

set_gain() {
    local new_gain=$1
    pw-cli s $NODE_ID Props "{\"params\": [\"gain_plugin:Gain\", $new_gain]}"
    if (( $(echo "$new_gain <= 0.001" | bc -l) )); then
        echo "Gain set to: $new_gain (silence)"
    else
        echo "Gain set to: $new_gain ($(echo "20 * l($new_gain)/l(10)" | bc -l | xargs printf "%.1f")dB)"
    fi
}

show_help() {
    echo "Master Gain Control"
    echo "Usage: $0 [option]"
    echo ""
    echo "Options:"
    echo "  current          Show current gain"
    echo "  <number>         Set gain to specific value (1.0 = unity)"
    echo "  +3, +6, +12     Boost current gain by X dB"
    echo "  -3, -6, -12     Cut current gain by X dB"
    echo "  reset           Reset to unity gain (1.0)"
    echo "  interactive     Interactive mode"
    echo "  debug           Show node ID and exit"
    echo ""
    echo "Examples:"
    echo "  $0 2.0          # Set gain to 2.0 (+6dB absolute)"
    echo "  $0 +3           # Boost current gain by 3dB (relative)"
    echo "  $0 -6           # Cut current gain by 6dB (relative)"
    echo "  $0 reset        # Reset to unity gain (1.0)"
}

interactive_mode() {
    while true; do
        echo ""
        show_current
        echo ""
        echo "Options:"
        echo "  1) +3dB boost    4) -3dB cut     7) Unity (reset)"
        echo "  2) +6dB boost    5) -6dB cut     8) Custom value"
        echo "  3) +12dB boost   6) -12dB cut    9) Exit"
        echo "  (Note: +/- options are relative to current gain)"
        echo ""
        read -p "Choose option: " choice
        
        case $choice in
            1) # +3dB boost
                current_gain=$(get_current_gain)
                if (( $(echo "$current_gain <= 0.001" | bc -l) )); then
                    set_gain 1.414  # Start from unity gain if at/near silence
                else
                    new_gain=$(echo "$current_gain * 1.414" | bc -l)
                    set_gain $new_gain
                fi
                ;;
            2) # +6dB boost
                current_gain=$(get_current_gain)
                if (( $(echo "$current_gain <= 0.001" | bc -l) )); then
                    set_gain 2.0  # Start from unity gain if at/near silence
                else
                    new_gain=$(echo "$current_gain * 2.0" | bc -l)
                    set_gain $new_gain
                fi
                ;;
            3) # +12dB boost
                current_gain=$(get_current_gain)
                if (( $(echo "$current_gain <= 0.001" | bc -l) )); then
                    set_gain 4.0  # Start from unity gain if at/near silence
                else
                    new_gain=$(echo "$current_gain * 4.0" | bc -l)
                    set_gain $new_gain
                fi
                ;;
            4) # -3dB cut
                current_gain=$(get_current_gain)
                if (( $(echo "$current_gain <= 0.001" | bc -l) )); then
                    echo "Cannot reduce gain: already at or near silence"
                else
                    new_gain=$(echo "$current_gain * 0.707" | bc -l)
                    set_gain $new_gain
                fi
                ;;
            5) # -6dB cut
                current_gain=$(get_current_gain)
                if (( $(echo "$current_gain <= 0.001" | bc -l) )); then
                    echo "Cannot reduce gain: already at or near silence"
                else
                    new_gain=$(echo "$current_gain * 0.5" | bc -l)
                    set_gain $new_gain
                fi
                ;;
            6) # -12dB cut
                current_gain=$(get_current_gain)
                if (( $(echo "$current_gain <= 0.001" | bc -l) )); then
                    echo "Cannot reduce gain: already at or near silence"
                else
                    new_gain=$(echo "$current_gain * 0.25" | bc -l)
                    set_gain $new_gain
                fi
                ;;
            7) # Unity (reset)
                set_gain 1.0
                ;;
            8) # Custom value
                read -p "Enter gain value: " custom_gain
                set_gain $custom_gain
                ;;
            9) exit 0 ;;
            *) echo "Invalid option" ;;
        esac
    done
}

# Main script logic
case $1 in
    current)
        show_current
        ;;
    debug)
        echo "Found Master Gain Input node ID: $NODE_ID"
        ;;
    +3)
        current_gain=$(get_current_gain)
        if (( $(echo "$current_gain <= 0.001" | bc -l) )); then
            set_gain 1.414  # Start from unity gain if at/near silence
        else
            new_gain=$(echo "$current_gain * 1.414" | bc -l)
            set_gain $new_gain
        fi
        ;;
    +6)
        current_gain=$(get_current_gain)
        if (( $(echo "$current_gain <= 0.001" | bc -l) )); then
            set_gain 2.0  # Start from unity gain if at/near silence
        else
            new_gain=$(echo "$current_gain * 2.0" | bc -l)
            set_gain $new_gain
        fi
        ;;
    +12)
        current_gain=$(get_current_gain)
        if (( $(echo "$current_gain <= 0.001" | bc -l) )); then
            set_gain 4.0  # Start from unity gain if at/near silence
        else
            new_gain=$(echo "$current_gain * 4.0" | bc -l)
            set_gain $new_gain
        fi
        ;;
    -3)
        current_gain=$(get_current_gain)
        if (( $(echo "$current_gain <= 0.001" | bc -l) )); then
            echo "Cannot reduce gain: already at or near silence"
        else
            new_gain=$(echo "$current_gain * 0.707" | bc -l)
            set_gain $new_gain
        fi
        ;;
    -6)
        current_gain=$(get_current_gain)
        if (( $(echo "$current_gain <= 0.001" | bc -l) )); then
            echo "Cannot reduce gain: already at or near silence"
        else
            new_gain=$(echo "$current_gain * 0.5" | bc -l)
            set_gain $new_gain
        fi
        ;;
    -12)
        current_gain=$(get_current_gain)
        if (( $(echo "$current_gain <= 0.001" | bc -l) )); then
            echo "Cannot reduce gain: already at or near silence"
        else
            new_gain=$(echo "$current_gain * 0.25" | bc -l)
            set_gain $new_gain
        fi
        ;;
    reset)
        set_gain 1.0
        ;;
    interactive)
        interactive_mode
        ;;
    "")
        interactive_mode
        ;;
    -h|--help)
        show_help
        ;;
    *)
        # Check if it's a number
        if [[ $1 =~ ^[0-9]+\.?[0-9]*$ ]]; then
            set_gain $1
        else
            echo "Invalid option: $1"
            show_help
            exit 1
        fi
        ;;
esac 