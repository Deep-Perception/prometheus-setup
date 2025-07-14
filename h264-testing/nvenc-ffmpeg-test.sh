#!/bin/bash

# Optional: check for root if needed for nvidia-smi or monitoring
if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo "❌ 'nvidia-smi' not found. Please ensure NVIDIA drivers are installed."
  exit 1
fi

# Check for NVENC support in ffmpeg
if ! ffmpeg -hide_banner -encoders 2>/dev/null | grep -q h264_nvenc; then
  echo "❌ FFmpeg is not compiled with NVENC support (h264_nvenc not found)."
  exit 1
fi

echo "✅ NVENC available via FFmpeg (h264_nvenc)."

# Clean up previous outputs
rm -f out*.mp4 log*.txt

echo "🚀 Launching 16 concurrent H.264 NVENC encoding jobs..."

# Launch 16 FFmpeg encode jobs using testsrc
for i in $(seq 0 15); do
  ffmpeg -f lavfi -i testsrc=size=1920x1080:rate=10 \
    -c:v h264_nvenc -preset fast -b:v 2M -t 120 out$i.mp4 \
    > log$i.txt 2>&1 &
done

# Wait for all background jobs
wait

echo "✅ All encoding jobs completed."

# Display last few lines of each log file
echo -e "\n📄 Summary of job outputs:\n"
for i in $(seq 0 15); do
  echo "=== log$i.txt ==="
  tail -n 10 log$i.txt
  echo
done
