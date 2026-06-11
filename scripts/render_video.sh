#!/bin/bash

# module load ffmpeg/6.1.1
/users/PZS1154/ericniu/FFmpeg/ffmpeg -r "$FRAMES_PER_SEC" -y -i "$OUTPUT_DIR/render_%04d.png" -vsync vfr -c:v libvpx-vp9 -b:v 16M -pix_fmt yuv420p "$OUTPUT_DIR/video.mp4"
