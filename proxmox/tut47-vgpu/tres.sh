#!/bin/bash
# tres.sh — lanza el MISMO transcode VAAPI a la vez en 9501, 9502, 9503
# y muestra la carga real de la GPU compartida mientras corren.
set -u

RESULTS=/root/vgpu/tres_results.txt
: > "$RESULTS"

for id in 9501 9502 9503; do
  (
    t0=$(date +%s)
    pct exec "$id" -- bash -c '
      export LIBVA_DRIVER_NAME=i965
      ffmpeg -y -hwaccel vaapi -vaapi_device /dev/dri/renderD128 \
        -i /root/origen.mp4 -vf format=nv12,hwupload \
        -c:v h264_vaapi -b:v 3M -an /root/gpu_tres.mp4
    ' >/tmp/tres_$id.log 2>&1
    ec=$?
    t1=$(date +%s)
    echo "CT $id: exit=$ec elapsed=$((t1 - t0))s" >> "$RESULTS"
  ) &
done

echo "=== 3 transcodes VAAPI lanzados en paralelo (9501 9502 9503) ==="
echo "=== carga GPU compartida (intel_gpu_top -l -s 1000) ==="
timeout 14 intel_gpu_top -l -s 1000

wait
echo ""
echo "=== resultados ==="
cat "$RESULTS"
