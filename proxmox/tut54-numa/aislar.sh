#!/bin/bash
# aislar.sh - reserva nucleos del hipervisor para la VM de tiempo real.
#
# Este servidor tiene 4 nucleos fisicos y 8 hilos: los hilos 0 y 4 son el MISMO
# nucleo, igual que 1-5, 2-6 y 3-7. Por eso no se reserva "4-7": eso serian los
# hermanos de 0-3 y seguirian peleandose por la misma unidad de ejecucion.
# Reservamos los nucleos fisicos 2 y 3 ENTEROS -> hilos 2,3,6,7.
#
# Y lo hacemos EN CALIENTE, sin reiniciar: con cgroups v2 le decimos a systemd que
# todo lo que no es una maquina virtual se quede en los hilos 0,1,4,5. Con
# --runtime no se escribe nada en disco: si algo va mal, se reinicia y ya esta.
set -e
SISTEMA="0,1,4,5"        # nucleos fisicos 0 y 1 -> para el hipervisor
RESERVADOS="2,3,6,7"     # nucleos fisicos 2 y 3 -> para tiempo real

for AMBITO in init.scope system.slice user.slice; do
  systemctl set-property --runtime "$AMBITO" AllowedCPUs=$SISTEMA
  echo "  $AMBITO  ->  hilos $SISTEMA"
done

echo
echo "lo que ve el kernel de verdad:"
for AMBITO in init.scope system.slice user.slice qemu.slice; do
  F="/sys/fs/cgroup/$AMBITO/cpuset.cpus.effective"
  printf "  %-14s %s\n" "$AMBITO" "$(cat $F 2>/dev/null || echo 'sin limite -> 0-7')"
done
echo
echo "nucleos fisicos 2 y 3 (hilos $RESERVADOS) reservados para tiempo real"
