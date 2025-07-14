#!/bin/bash

# Ensure script is run as root (for /dev/dri access)
if [ "$EUID" -ne 0 ]; then
  echo "⚠️  Please run this script as root: sudo $0"
  exit 1
fi

# Find a VAAPI-capable render device
echo "🔍 Scanning for VAAPI-capable render device..."
for dev in /dev/dri/renderD*; do
  if vainfo --device="$dev" &>/dev/null; then
    VAAPI_DEV="$dev"
    echo "✅ VAAPI supported on $VAAPI_DEV"
    break
  fi
done

if [ -z "$VAAPI_DEV" ]; then
  echo "❌ No VAAPI-capable device found."
  exit 1
fi

# Clean up previous logs
rm -f out*.mp4 log*.txt

echo "🚀 Launching 16 concurrent VAAPI H.264 encoding jobs..."

# Launch 16 ffmpeg jobs in background, logging output
for i in $(seq 0 15); do
  ffmpeg -vaapi_device "$VAAPI_DEV" \
    -f lavfi -i testsrc=size=1920x1080:rate=10 \
    -vf 'format=nv12,hwupload' \
    -c:v h264_vaapi -b:v 2M -t 120 out$i.mp4 \
    > log$i.txt 2>&1 &
done

# Wait for all jobs
wait

echo "✅ All jobs complete."

# Show summarized output
echo -e "\n📄 Summary of job outputs:\n"

for i in $(seq 0 15); do
  echo "=== log$i.txt ==="
  tail -n 10 log$i.txt
  echo
done
