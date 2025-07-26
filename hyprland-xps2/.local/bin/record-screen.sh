#!/usr/bin/env bash

set -x

VIDEO_CODEC="h264_nvenc"
PIXEL_FORMAT="yuv420p"
AUDIO_CODEC="libmp3lame"
VC_PARAMS="-p hwaccel=cuda -p hwaccel_output_format=cuda -p b=5M"

ALL_PARAMS="$VC_PARAMS --codec $VIDEO_CODEC --audio-codec $AUDIO_CODEC --pixel-format $PIXEL_FORMAT"

getdate() {
    date '+%Y-%m-%d_%H.%M.%S'
}
getaudiooutput() {
    # pactl list sources | grep 'Name' | grep 'monitor' | cut -d ' ' -f2
    echo "master_sink.monitor"
}
getactivemonitor() {
    hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name'
}

mkdir -p "$(xdg-user-dir VIDEOS)"
cd "$(xdg-user-dir VIDEOS)" || exit
if pgrep wf-recorder > /dev/null; then
    notify-send "Recording Stopped" "Stopped" -a 'record-script.sh' &
    pkill wf-recorder &
else
    notify-send "Starting recording" 'recording_'"$(getdate)"'.mp4' -a 'record-script.sh'
    if [[ "$1" == "--sound" ]]; then
        wf-recorder $ALL_PARAMS -f './recording_'"$(getdate)"'.mp4' --geometry "$(slurp)" --audio="$(getaudiooutput)" & disown
    elif [[ "$1" == "--fullscreen-sound" ]]; then
        wf-recorder $ALL_PARAMS -o $(getactivemonitor) -f './recording_'"$(getdate)"'.mp4' --audio="$(getaudiooutput)" & disown
    elif [[ "$1" == "--fullscreen" ]]; then
        wf-recorder $ALL_PARAMS -o $(getactivemonitor) -f './recording_'"$(getdate)"'.mp4' & disown
    else
        wf-recorder $ALL_PARAMS -f './recording_'"$(getdate)"'.mp4' --geometry "$(slurp)" & disown
    fi
fi
