#!/bin/bash
# Buzon de facturas: procesa TODO lo que haya en entrada/ y lo deja VACIO.
# Lo dispara procesar.path cuando llega algo, no un cron cada minuto.
set -u
BASE=/home/homelab/lab/eventos
IN="$BASE/entrada"; OK="$BASE/procesadas"; KO="$BASE/rechazadas"; LOG="$BASE/registro.log"
shopt -s nullglob dotglob

for f in "$IN"/*; do
  [ -f "$f" ] || continue
  n="$(basename -- "$f")"
  if [[ "$n" == *.csv ]]; then
    d="$OK/$(date +%Y-%m-%d)"; mkdir -p "$d"
    lineas=$(wc -l < "$f")
    mv --backup=numbered -- "$f" "$d/$n"
    printf '%s  OK         %-24s %5s lineas\n' "$(date +%H:%M:%S.%3N)" "$n" "$lineas" >> "$LOG"
  else
    # REGLA DE ORO con DirectoryNotEmpty: lo que se queda aqui vuelve a
    # disparar la unidad EN BUCLE. El buzon se vacia SIEMPRE, pase lo que pase.
    mv --backup=numbered -- "$f" "$KO/$n"
    printf '%s  RECHAZADO  %-24s (no es .csv)\n' "$(date +%H:%M:%S.%3N)" "$n" >> "$LOG"
  fi
done
