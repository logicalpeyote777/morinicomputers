#!/bin/bash
# Transcodifica minuto y medio de pelicula 1080p a 720p 3 Mbps: el trabajo
# exacto que hace Jellyfin cuando el movil no puede con el fichero original.
#   bench.sh cpu  -> decodificar, escalar y codificar en el PROCESADOR (libx264)
#   bench.sh gpu  -> las tres cosas DENTRO de la GPU (VAAPI), sin volver a memoria
PELI="/media/peliculas/El Ultimo Tren (2019)/El Ultimo Tren (2019) 1080p.mkv"
FF="/usr/lib/jellyfin-ffmpeg/ffmpeg -hide_banner -loglevel error -stats -t 90"

medir() {           # lanza ffmpeg y, MIENTRAS trabaja, mide la CPU del contenedor
  "$@" 2>/tmp/ff.log & local pid=$!
  sleep 4
  echo "   CPU del contenedor: $(docker stats --no-stream --format '{{.CPUPerc}}' jellyfin)"
  echo "   CPU del contenedor: $(docker stats --no-stream --format '{{.CPUPerc}}' jellyfin)"
  wait $pid
  echo "   $(tr '\r' '\n' </tmp/ff.log | tail -1)"
}

case "$1" in
  cpu) echo "== TRANSCODIFICANDO POR PROCESADOR (libx264) =="
       medir docker exec jellyfin $FF -i "$PELI" \
         -vf scale=1280:720 -c:v libx264 -preset veryfast -b:v 3M -an -f null - ;;
  gpu) echo "== TRANSCODIFICANDO POR GPU (VAAPI) =="
       medir docker exec jellyfin $FF \
         -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 -hwaccel_output_format vaapi \
         -i "$PELI" -vf scale_vaapi=w=1280:h=720 -c:v h264_vaapi -b:v 3M -an -f null - ;;
  *)   echo "uso: bench.sh {cpu|gpu}" ;;
esac
