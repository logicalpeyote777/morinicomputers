#!/bin/bash
# La MISMA copia, hecha bien: se escribe fuera del buzon y entra con un mv.
# mv en el mismo sistema de ficheros es rename(2): o esta entero, o no esta.
set -u
BASE=/home/homelab/lab/eventos
T="$BASE/tmp/facturas-agosto.csv"
echo "fecha;cliente;concepto;importe" > "$T"
for i in $(seq 1 2000); do
  printf '2026-08-%02d;CLIENTE-%04d;factura;%d,00\n' $((i%28+1)) $i $((i*7)) >> "$T"
  (( i % 100 )) || sleep 0.30
done
mv -- "$T" "$BASE/entrada/"
echo "copia terminada: 2001 lineas, entregadas de una pieza"
