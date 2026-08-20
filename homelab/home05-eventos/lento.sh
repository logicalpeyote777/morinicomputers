#!/bin/bash
# Lo que hace un scp o un rsync sin mas: ESCRIBE DENTRO del buzon, y el
# fichero va creciendo. El vigilante no espera a que termine la copia.
set -u
D=/home/homelab/lab/eventos/entrada/facturas-agosto.csv
echo "fecha;cliente;concepto;importe" > "$D"
for i in $(seq 1 2000); do
  printf '2026-08-%02d;CLIENTE-%04d;factura;%d,00\n' $((i%28+1)) $i $((i*7)) >> "$D"
  (( i % 100 )) || sleep 0.30
done
echo "copia terminada: 2001 lineas escritas"
