for i in $(seq 0 15); do
  ffmpeg -f lavfi -i testsrc=size=1920x1080:rate=10 -t 120 \
    -c:v h264_nvenc -preset fast out$i.mp4 &
done
wait
