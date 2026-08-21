#!/bin/bash
# superficie.sh — ¿el autotest CORTO lee de verdad tu disco? Hagamos la cuenta.
# Mide la velocidad real del disco y la compara con lo que dura cada prueba.
DEV=${1:-/dev/sdb}

TAM=$(( $(sudo blockdev --getsize64 "$DEV") / 1000000 ))              # MB reales
T0=$(date +%s%N)
sudo dd if="$DEV" of=/dev/null bs=1M count=1500 iflag=direct 2>/dev/null
T1=$(date +%s%N)
VEL=$(( 1500 * 1048576 / ((T1-T0)/1000000) / 1000 ))                   # MB/s medidos

C=$(sudo smartctl -c "$DEV" | awk '/Short self-test routine/{getline; gsub(/[^0-9]/,""); print}')
L=$(sudo smartctl -c "$DEV" | awk '/Extended self-test routine/{getline; gsub(/[^0-9]/,""); print}')
pct() { awk -v v="$1" -v m="$2" -v t="$TAM" 'BEGIN{printf "%.1f", v*m*60*100/t}'; }

echo "disco $DEV: $((TAM/1000)) GB   velocidad real MEDIDA ahora: $VEL MB/s"
echo "leer la superficie entera tardaria: $((TAM/VEL/60)) min"
echo
echo "test CORTO     declara $C min  ->  da para $((VEL*C*60/1000)) GB = $(pct $VEL $C)% del disco"
echo "test EXTENDIDO declara $L min  ->  da para $((VEL*L*60/1000)) GB = $(pct $VEL $L)% del disco"
echo
echo "conclusion: el corto NO mira tu superficie. El que encuentra sectores"
echo "pendientes (atributo 197) es el EXTENDIDO, y por eso se programa de noche."
