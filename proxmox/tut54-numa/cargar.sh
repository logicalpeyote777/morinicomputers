#!/bin/bash
# cargar.sh - simula el "vecino ruidoso" del hipervisor: los backups de la noche,
# otra VM compilando, un contenedor indexando... Ocupa los 8 hilos del servidor.
# Es la MISMA carga en la medicion de antes y en la de despues: solo asi la
# comparacion es honesta.
pkill -f carga-pyme 2>/dev/null
sleep 1
for i in $(seq 1 8); do
  setsid bash -c 'exec -a carga-pyme bash -c "while :; do :; done"' >/dev/null 2>&1 &
done
sleep 3
echo "carga activa: $(pgrep -fc carga-pyme) procesos ocupando la CPU del servidor"
uptime
