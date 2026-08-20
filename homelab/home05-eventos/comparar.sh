#!/bin/bash
# Las dos medidas REALES de este laboratorio, cuatro entregas cada una.
BASE=/home/homelab/lab/eventos
read C CX <<< "$(grep -w cron "$BASE/resultados.txt" | tail -1 | awk '{print $6, $9}')"
read P PX <<< "$(grep -w path "$BASE/resultados.txt" | tail -1 | awk '{print $6, $9}')"
echo
printf '   %-32s %10s %10s %16s\n' "COMO SE ENTERA DE QUE HA LLEGADO" "MEDIA" "PEOR CASO" "ARRANQUES/DIA"
printf '   %-32s %10s %10s %16s\n' "--------------------------------" "--------" "---------" "----------------"
printf '   %-32s %8.2f s %8.2f s %16s\n' "cron  * * * * *    (sondear)"   "$C" "$CX" "1440"
printf '   %-32s %8.2f s %8.2f s %16s\n' "systemd .path      (reaccionar)" "$P" "$PX" "solo si llega algo"
echo
awk -v c="$C" -v p="$P" 'BEGIN{printf "   => %.0f veces mas rapido de media, y sin despertar la maquina 1439 veces para nada\n\n", c/p}'
