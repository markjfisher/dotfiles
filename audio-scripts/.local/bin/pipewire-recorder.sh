#!/bin/bash

# PipeWire Recorder Script
# Records from the recorder_sink monitor

RECORDING_DIR="$HOME/Recordings"
RECORDER_SINK="recorder_sink"
RECORDER_MONITOR="${RECORDER_SINK}.monitor"
PID_FILE="/tmp/pipewire_recorder.pid"

# MP3 encoding settings
MP3_BITRATE="192"  # Change to 128, 192, 256, 320 as desired
AUTO_CONVERT_TO_MP3=false  # Set to true to automatically convert after recording

# Recording parameters - make these configurable
DEFAULT_CHANNELS="2"
DEFAULT_RATE="48000"
DEFAULT_FORMAT="s16"

# Allow overrides via environment variables
CHANNELS="${PW_CHANNELS:-$DEFAULT_CHANNELS}"
RATE="${PW_RATE:-$DEFAULT_RATE}"
FORMAT="${PW_FORMAT:-$DEFAULT_FORMAT}"

# Create recordings directory if it doesn't exist
mkdir -p "$RECORDING_DIR"

# Function to show audio device capabilities
show_audio_info() {
    echo "=== PipeWire Audio Device Information ==="
    echo ""
    
    # Use wpctl for cleaner output if available
    if command -v wpctl &> /dev/null; then
        echo "--- Audio Devices (wpctl) ---"
        wpctl status
        echo ""
    fi
    
    echo "--- Available Sources (Inputs) ---"
    pactl list sources short
    echo ""
    
    echo "--- Available Sinks (Outputs) ---"
    pactl list sinks short
    echo ""
    
    echo "--- Recorder Sink Status ---"
    pactl list sinks | grep -A 10 -B 5 "recorder_sink" || echo "Recorder sink not found"
    echo ""
    
    echo "--- Default Source Details ---"
    local default_source=$(pactl info | grep "Default Source:" | cut -d' ' -f3)
    if [ -n "$default_source" ]; then
        echo "Default Source: $default_source"
        pactl list sources | grep -A 20 "Name: $default_source" | grep -E "(Sample Specification|Channel Map|Properties)"
    fi
    echo ""
    
    echo "--- Current Recording Parameters ---"
    echo "Channels: $CHANNELS"
    echo "Sample Rate: $RATE Hz"
    echo "Format: $FORMAT"
    echo "Target: $RECORDER_MONITOR"
    echo ""
    
    echo "--- PipeWire Node Information ---"
    pw-dump | jq -r '
        .[] | 
        select(.info.props."media.class" // "" | test("Audio/(Source|Sink)")) |
        "\(.info.props."node.description" // .info.props."node.name" // "Unknown") - \(.info.props."media.class" // "Unknown")"
    ' 2>/dev/null || {
        echo "jq not available, using basic pw-cli info:"
        pw-cli list-objects | grep -E "(Node|id)"
    }
    echo ""
}

# Function to test recording capabilities
test_recording_params() {
    echo "=== Testing Recording Parameters ==="
    echo ""
    
    # Test different common sample rates
    local test_rates=("44100" "48000" "96000")
    local test_formats=("s16" "s24" "f32")
    
    echo "Testing pw-record with different parameters..."
    echo "(This will create short test files to verify compatibility)"
    echo ""
    
    for rate in "${test_rates[@]}"; do
        for format in "${test_formats[@]}"; do
            local test_file="/tmp/test_${rate}_${format}.wav"
            echo -n "Testing ${rate}Hz ${format}: "
            
            # Try to record for 1 second
            timeout 1s pw-record --target "$RECORDER_MONITOR" \
                --channels "$CHANNELS" --rate "$rate" --format "$format" \
                "$test_file" 2>/dev/null
                
            if [ $? -eq 0 ] && [ -f "$test_file" ] && [ -s "$test_file" ]; then
                local size=$(stat -c%s "$test_file")
                echo "OK (${size} bytes)"
            else
                echo "FAILED"
            fi
            
            # Clean up test file
            rm -f "$test_file"
        done
    done
    echo ""
}

# Function to show microphone levels
show_mic_levels() {
    echo "=== Microphone Level Monitor ==="
    echo "This will show real-time audio levels from your microphone."
    echo "Speak into your mic - you should see level changes."
    echo "Press Ctrl+C to stop."
    echo ""
    
    # Find the default source (microphone)
    local default_source=$(pactl info | grep "Default Source:" | cut -d' ' -f3)
    echo "Monitoring source: $default_source"
    echo ""
    
    # Check if we have pw-mon or other monitoring tools
    if command -v pw-mon &> /dev/null; then
        echo "Using pw-mon for real-time monitoring..."
        echo "You should see level indicators when speaking."
        echo ""
        pw-mon 2>/dev/null &
        PW_MON_PID=$!
        
        echo "Press Enter to stop monitoring..."
        read -r
        kill $PW_MON_PID 2>/dev/null
        
    elif command -v pactl &> /dev/null; then
        echo "Using pactl for source monitoring..."
        echo "Current source levels:"
        pactl list sources | grep -E "(Name:|Volume:|Mute:|Description:)" | head -20
        echo ""
        echo "To see real-time levels, you can use:"
        echo "  pavucontrol  (GUI)"
        echo "  or install: sudo pacman -S pulsemixer"
        echo ""
        
    else
        echo "No suitable monitoring tool found."
        echo "Install one of: pavucontrol, pulsemixer, or ensure pw-mon is available"
    fi
}

# Function to check and adjust microphone settings
check_mic_settings() {
    echo "=== Microphone Settings Diagnostic ==="
    echo ""
    
    # Get the default source (microphone)
    local default_source=$(pactl info | grep "Default Source:" | cut -d' ' -f3)
    echo "Default microphone: $default_source"
    echo ""
    
    echo "--- Current Microphone Levels ---"
    pactl list sources | grep -A 15 "Name: $default_source" | grep -E "(Volume:|Mute:|Base Volume:)"
    echo ""
    
    echo "--- ALSA Mixer Settings (Hardware Level) ---"
    if command -v amixer &> /dev/null; then
        echo "Capture levels:"
        amixer sget Capture 2>/dev/null || echo "No 'Capture' control found"
        echo ""
        
        echo "Microphone boost:"
        amixer sget "Mic Boost" 2>/dev/null || amixer sget "Internal Mic Boost" 2>/dev/null || echo "No mic boost control found"
        echo ""
        
        echo "Auto Gain Control:"
        amixer sget "Auto Gain Control" 2>/dev/null || echo "No AGC control found (this is often good)"
        echo ""
        
        echo "All capture-related controls:"
        amixer scontrols | grep -i -E "(capture|mic|boost|gain|agc)"
    else
        echo "amixer not available - install alsa-utils: sudo pacman -S alsa-utils"
    fi
    echo ""
    
    echo "--- PulseAudio Source Properties ---"
    pactl list sources | grep -A 30 "Name: $default_source" | grep -E "(Properties:|device\.|alsa\.)"
    echo ""
    
    echo "--- Suggested Fixes ---"
    echo "1. Lower microphone gain:"
    echo "   pactl set-source-volume $default_source 50%"
    echo ""
    echo "2. Check for hardware AGC (if amixer shows AGC controls):"
    echo "   amixer sset 'Auto Gain Control' off"
    echo ""
    echo "3. Lower hardware mic boost:"
    echo "   amixer sset 'Mic Boost' 0   # or try 1, 2"
    echo ""
    echo "4. Lower capture level:"
    echo "   amixer sset Capture 50%"
    echo ""
    echo "5. Open pavucontrol for GUI adjustment:"
    echo "   pavucontrol &"
    echo ""
}

# Function to apply common microphone fixes
fix_mic_levels() {
    echo "=== Applying Common Microphone Fixes ==="
    echo ""
    
    local default_source=$(pactl info | grep "Default Source:" | cut -d' ' -f3)
    echo "Fixing microphone: $default_source"
    echo ""
    
    echo "1. Setting PulseAudio source volume to 60%..."
    pactl set-source-volume "$default_source" 60%
    echo ""
    
    if command -v amixer &> /dev/null; then
        echo "2. Attempting to disable Auto Gain Control..."
        amixer sset "Auto Gain Control" off 2>/dev/null && echo "   AGC disabled" || echo "   No AGC control found"
        
        echo "3. Setting mic boost to low level..."
        amixer sset "Mic Boost" 1 2>/dev/null && echo "   Mic boost set to 1" || echo "   No mic boost control found"
        
        echo "4. Setting capture level to 60%..."
        amixer sset Capture 60% 2>/dev/null && echo "   Capture level set to 60%" || echo "   No capture control found"
        
        echo "5. Checking for other boost controls..."
        amixer sset "Internal Mic Boost" 1 2>/dev/null && echo "   Internal mic boost set to 1" || echo "   No internal mic boost found"
    else
        echo "amixer not available - install alsa-utils for hardware controls"
    fi
    
    echo ""
    echo "--- New Settings ---"
    pactl list sources | grep -A 8 "Name: $default_source" | grep -E "(Volume:|Mute:)"
    echo ""
    echo "Test recording now with: $0 start"
    echo "If still distorted, try even lower levels (40%, 30%, etc.)"
}

# Function to convert WAV to MP3
convert_to_mp3() {
    local wav_file="$1"
    local mp3_file="${wav_file%.wav}.mp3"
    
    if [ ! -f "$wav_file" ]; then
        echo "Error: WAV file not found: $wav_file"
        return 1
    fi
    
    if ! command -v ffmpeg &> /dev/null; then
        echo "Error: ffmpeg not found. Install with: sudo pacman -S ffmpeg"
        return 1
    fi
    
    echo "Converting to MP3 (${MP3_BITRATE}k)..."
    ffmpeg -i "$wav_file" -b:a ${MP3_BITRATE}k "$mp3_file" -y
    
    if [ $? -eq 0 ]; then
        echo "MP3 created: $mp3_file"
        
        # Ask if user wants to keep the WAV file
        echo -n "Keep original WAV file? (y/n): "
        read -r keep_wav
        if [[ "$keep_wav" =~ ^[Nn]$ ]]; then
            rm "$wav_file"
            echo "Original WAV file deleted"
        fi
    else
        echo "Error: MP3 conversion failed"
        return 1
    fi
}

# Function to start recording
start_recording() {
    if [ -f "$PID_FILE" ]; then
        echo "Recording is already running (PID: $(cat $PID_FILE))"
        return 1
    fi
    
    # Generate filename with timestamp
    FILENAME="recording_$(date +%Y%m%d_%H%M%S).wav"
    FILEPATH="$RECORDING_DIR/$FILENAME"
    
    echo "Starting recording to: $FILEPATH"
    echo "Connect audio sources to 'Recorder Sink' in qpwgraph"
    echo ""
    
    # Start recording in the background
    pw-record --target "$RECORDER_MONITOR" --channels "$CHANNELS" --rate "$RATE" --format "$FORMAT" "$FILEPATH" &
    RECORD_PID=$!
    
    # Save PID for later management
    echo $RECORD_PID > "$PID_FILE"
    
    echo "Recording started (PID: $RECORD_PID)"
    echo "Use '$0 stop' to stop recording"
    echo "Use '$0 status' to check recording status"
}

# Function to stop recording
stop_recording() {
    if [ ! -f "$PID_FILE" ]; then
        echo "No recording is currently running"
        return 1
    fi
    
    RECORD_PID=$(cat "$PID_FILE")
    
    if kill -0 "$RECORD_PID" 2>/dev/null; then
        echo "Stopping recording (PID: $RECORD_PID)"
        kill "$RECORD_PID"
        rm -f "$PID_FILE"
        echo "Recording stopped"
        
        # Auto-convert to MP3 if enabled
        if [ "$AUTO_CONVERT_TO_MP3" = true ]; then
            # Find the most recent WAV file
            LATEST_WAV=$(ls -t "$RECORDING_DIR"/*.wav 2>/dev/null | head -1)
            if [ -n "$LATEST_WAV" ]; then
                echo ""
                convert_to_mp3 "$LATEST_WAV"
            fi
        fi
    else
        echo "Recording process not found, cleaning up PID file"
        rm -f "$PID_FILE"
    fi
}

# Function to check recording status
check_status() {
    if [ -f "$PID_FILE" ]; then
        RECORD_PID=$(cat "$PID_FILE")
        if kill -0 "$RECORD_PID" 2>/dev/null; then
            echo "Recording is running (PID: $RECORD_PID)"
            echo "Recording to: $(ps -o args= -p $RECORD_PID | grep -o '[^ ]*\.wav')"
        else
            echo "PID file exists but process not running, cleaning up"
            rm -f "$PID_FILE"
        fi
    else
        echo "No recording is currently running"
    fi
}

# Function to list recent recordings
list_recordings() {
    echo "Recent recordings in $RECORDING_DIR:"
    ls -lt "$RECORDING_DIR"/*.{wav,mp3} 2>/dev/null | head -10 || echo "No recordings found"
}

# Function to convert existing WAV files to MP3
convert_existing() {
    local pattern="$1"
    
    if [ -z "$pattern" ]; then
        echo "Available WAV files:"
        ls -1 "$RECORDING_DIR"/*.wav 2>/dev/null || echo "No WAV files found"
        echo ""
        echo "Usage: $0 convert <filename.wav>"
        echo "   or: $0 convert all"
        return 1
    fi
    
    if [ "$pattern" = "all" ]; then
        for wav_file in "$RECORDING_DIR"/*.wav; do
            if [ -f "$wav_file" ]; then
                convert_to_mp3 "$wav_file"
            fi
        done
    else
        # Handle both full path and just filename
        if [[ "$pattern" == *"/"* ]]; then
            convert_to_mp3 "$pattern"
        else
            convert_to_mp3 "$RECORDING_DIR/$pattern"
        fi
    fi
}

# Interactive recording mode
interactive_mode() {
    echo "=== PipeWire Recorder Interactive Mode ==="
    echo "1. Use qpwgraph to connect audio sources to 'Recorder Sink'"
    echo "2. Press Enter to start recording..."
    read -r
    
    start_recording
    
    if [ $? -eq 0 ]; then
        echo ""
        echo "Recording in progress..."
        echo "Press Enter to stop recording..."
        read -r
        stop_recording
    fi
}

# Main script logic
case "$1" in
    start)
        start_recording
        ;;
    stop)
        stop_recording
        ;;
    status)
        check_status
        ;;
    list)
        list_recordings
        ;;
    convert)
        convert_existing "$2"
        ;;
    info)
        show_audio_info
        ;;
    test)
        test_recording_params
        ;;
    levels)
        show_mic_levels
        ;;
    check)
        check_mic_settings
        ;;
    fix)
        fix_mic_levels
        ;;
    interactive|"")
        interactive_mode
        ;;
    *)
        echo "Usage: $0 [start|stop|status|list|convert|info|test|levels|check|fix|interactive]"
        echo ""
        echo "Commands:"
        echo "  start       - Start recording"
        echo "  stop        - Stop recording"
        echo "  status      - Check recording status"
        echo "  list        - List recent recordings"
        echo "  convert     - Convert WAV to MP3"
        echo "                Examples: $0 convert recording.wav"
        echo "                         $0 convert all"
        echo "  info        - Show audio device information"
        echo "  test        - Test different recording parameters"
        echo "  levels      - Monitor microphone levels"
        echo "  check       - Check microphone gain/AGC settings"
        echo "  fix         - Apply common microphone fixes"
        echo "  interactive - Interactive mode (default)"
        echo ""
        echo "Configuration:"
        echo "  MP3 bitrate: ${MP3_BITRATE}k"
        echo "  Auto-convert: $AUTO_CONVERT_TO_MP3"
        echo "  Recordings saved to: $RECORDING_DIR"
        echo "  Recording params: ${CHANNELS}ch, ${RATE}Hz, ${FORMAT}"
        echo ""
        echo "Environment variables (to override defaults):"
        echo "  PW_CHANNELS=1|2    - Number of channels"
        echo "  PW_RATE=44100|48000|96000 - Sample rate"
        echo "  PW_FORMAT=s16|s24|f32 - Audio format"
        echo ""
        echo "To enable auto-conversion, edit the script and set:"
        echo "  AUTO_CONVERT_TO_MP3=true"
        exit 1
        ;;
esac 
