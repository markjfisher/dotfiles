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

# Create recordings directory if it doesn't exist
mkdir -p "$RECORDING_DIR"

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
    pw-record --target "$RECORDER_MONITOR" --channels 2 --rate 48000 --format s16 "$FILEPATH" &
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
    interactive|"")
        interactive_mode
        ;;
    *)
        echo "Usage: $0 [start|stop|status|list|convert|interactive]"
        echo ""
        echo "Commands:"
        echo "  start       - Start recording"
        echo "  stop        - Stop recording"
        echo "  status      - Check recording status"
        echo "  list        - List recent recordings"
        echo "  convert     - Convert WAV to MP3"
        echo "                Examples: $0 convert recording.wav"
        echo "                         $0 convert all"
        echo "  interactive - Interactive mode (default)"
        echo ""
        echo "Configuration:"
        echo "  MP3 bitrate: ${MP3_BITRATE}k"
        echo "  Auto-convert: $AUTO_CONVERT_TO_MP3"
        echo "  Recordings saved to: $RECORDING_DIR"
        echo ""
        echo "To enable auto-conversion, edit the script and set:"
        echo "  AUTO_CONVERT_TO_MP3=true"
        exit 1
        ;;
esac 
