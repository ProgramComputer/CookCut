#!/bin/sh
set -e

# Check if FFmpeg is installed and working
echo "Checking FFmpeg installation..."
ffmpeg -version

# Create required directories if they don't exist
mkdir -p /tmp/ffmpeg/uploads
mkdir -p /tmp/ffmpeg/output

# Set proper permissions
chmod 777 /tmp/ffmpeg/uploads
chmod 777 /tmp/ffmpeg/output

echo "\nStarting FFmpeg Server..."
echo "-------------------------"

# Execute the main container command
exec "$@" 