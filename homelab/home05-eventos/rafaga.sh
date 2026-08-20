#!/bin/bash
# 20 facturas de golpe: UN disparo tiene que vaciar el buzon entero.
set -u
BASE=/home/homelab/lab/eventos
for i in $(seq 1 20); do
  printf 'fecha;cliente;importe\n2026-08-20;CLIENTE-%02d;%d,00\n' "$i" $((i*100)) > "$BASE/tmp/lote-$i.csv"
done
mv "$BASE"/tmp/lote-*.csv "$BASE/entrada/"
echo "20 facturas entregadas de golpe"
