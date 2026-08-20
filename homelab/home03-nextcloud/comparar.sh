#!/bin/bash
# comparar.sh — la misma prueba, la misma maquina, los dos montajes.
A=$(cat ~/.bench-sqlite 2>/dev/null); B=$(cat ~/.bench-postgres 2>/dev/null)
[ -n "$A" ] && [ -n "$B" ] || { echo "faltan mediciones: lanza bench.sh sqlite y bench.sh postgres"; exit 1; }
N=24
echo
echo "  ==  MISMA MAQUINA  ·  MISMA PRUEBA  ·  $N subidas simultaneas  =="
echo
printf "  compose de 3 lineas   SQLite, sin cache, sin cron    %s\n" \
       "$(awk -v t=$A -v n=$N 'BEGIN{printf "%6.1f s   %4.1f fich/s", t/1000, n/(t/1000)}')"
printf "  compose EN SERIO      Postgres + Redis + cron        %s\n" \
       "$(awk -v t=$B -v n=$N 'BEGIN{printf "%6.1f s   %4.1f fich/s", t/1000, n/(t/1000)}')"
echo "                                                        -----------------------"
awk -v a=$A -v b=$B 'BEGIN{printf "                                                        %.1f VECES mas rapido\n", a/b}'
echo
echo "  Mismo hardware. Mismos ficheros. Cambia lo que hay DEBAJO."
echo
