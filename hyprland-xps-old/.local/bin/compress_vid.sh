#!/bin/bash

# Default height if not specified
height=1080

# Parse command line arguments
while getopts "y:" opt; do
    case $opt in
        y) height="$OPTARG"
        ;;
        \?) echo "Invalid option -$OPTARG" >&2
            exit 1
        ;;
    esac
done

# Shift past the options to get the input file
shift $((OPTIND-1))

# Check if input file was provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 [-y height] input_file"
    echo "  -y height    Set output height (default: 1080)"
    exit 1
fi

input_file="$1"

# Check if input file exists
if [ ! -f "$input_file" ]; then
    echo "Error: Input file '$input_file' does not exist"
    exit 1
fi

# Generate output filename by adding _comp before the extension
filename="${input_file%.*}"
extension="${input_file##*.}"
output_file="${filename}_comp.${extension}"

# Run ffmpeg with CUDA acceleration
ffmpeg -y \
    -hwaccel cuda \
    -hwaccel_output_format cuda \
    -i "$input_file" \
    -c:a copy \
    -vf "scale_cuda=-1:${height}" \
    -c:v h264_nvenc \
    -b:v 5M \
    "$output_file"

# Check if ffmpeg was successful
if [ $? -eq 0 ]; then
    echo "Successfully compressed video to $output_file"
    echo "Original file: $(du -h "$input_file" | cut -f1)"
    echo "Compressed file: $(du -h "$output_file" | cut -f1)"
else
    echo "Error: FFmpeg compression failed"
    exit 1
fi

