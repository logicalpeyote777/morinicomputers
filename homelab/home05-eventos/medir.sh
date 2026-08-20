#!/bin/bash
# Mide lo que tarda una factura en procesarse desde que entra en el buzon.
# CUATRO entregas, no una: con cron la latencia es una loteria y una sola
# medida no demuestra nada. Y se reparten a proposito por todo el minuto,
# para no hacer trampas ni a favor ni en contra.
#   uso:  medir.sh cron|path
set -u
BASE=/home/homelab/lab/eventos
ETQ="${1:-prueba}"
ESPERA=(0 13 27 41)          # segundos de desfase entre entrega y entrega
: > "$BASE/.ultimas"

for i in 0 1 2 3; do
  sleep "${ESPERA[$i]}"
  N="factura-$(date +%H%M%S).csv"
  # se escribe FUERA del buzon y se entrega con un mv: o entra entera, o no entra
  printf 'fecha;cliente;importe\n2026-08-20;ACME SL;1240,00\n' > "$BASE/tmp/$N"
  T0=$(date +%s.%N)
  mv "$BASE/tmp/$N" "$BASE/entrada/$N"
  while ! find "$BASE/procesadas" -name "$N" -print -quit | grep -q . ; do sleep 0.02; done
  T1=$(date +%s.%N)
  awk -v a="$T1" -v b="$T0" -v n=$((i+1)) \
      'BEGIN{printf "   entrega %d ..........  %6.2f s\n", n, a-b}' | tee -a "$BASE/.ultimas"
done

awk -v e="$ETQ" '{v=$4; s+=v; if(m==""||v<m)m=v; if(v>M)M=v}
     END{printf "   -----------------------------------------------------------\n";
         printf "   %-5s   min %6.2f s   media %6.2f s   peor %6.2f s\n", e, m, s/NR, M}' \
    "$BASE/.ultimas" | tee -a "$BASE/resultados.txt"
