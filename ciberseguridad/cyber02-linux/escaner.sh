#!/bin/bash
# escaner.sh - mini comprobador de host y puertos para el laboratorio aislado.
# Demuestra lo esencial de bash para hacking: variable de entrada, ping y bucle.
# Uso:  ./escaner.sh <ip>     (por defecto, la victima del lab 10.13.37.20)
# Solo contra maquinas tuyas. Laboratorio propio y aislado.

OBJETIVO="${1:-10.13.37.20}"      # 1er argumento; si falta, usa la victima
PUERTOS="21 22 80 443 3306"        # puertos a comprobar

echo "[*] Objetivo: $OBJETIVO"

# Esta vivo? un ping con timeout corto
if ping -c1 -W1 "$OBJETIVO" >/dev/null 2>&1; then
  echo "[+] host VIVO"
else
  echo "[-] host no responde"; exit 1
fi

# Comprueba cada puerto con netcat en modo sondeo (-z, sin enviar datos)
for p in $PUERTOS; do
  if nc -z -w1 "$OBJETIVO" "$p" 2>/dev/null; then
    echo "[+] puerto $p  ABIERTO"
  else
    echo "[-] puerto $p  cerrado"
  fi
done
