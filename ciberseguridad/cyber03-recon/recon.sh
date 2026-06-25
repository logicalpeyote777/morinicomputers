#!/usr/bin/env bash
# recon.sh — reconocimiento por etapas contra UNA maquina de TU laboratorio.
# Uso:  ./recon.sh <ip>     (por defecto, la victima del lab: 10.13.37.20)
# SOLO para sistemas propios y autorizados. Laboratorio aislado, sin salida a internet.
# Morini Computers — Ciberseguridad. Encuadre educativo y de defensa.
set -u
OBJETIVO="${1:-10.13.37.20}"
echo "[*] Objetivo: $OBJETIVO"

echo "[1] Esta vivo el host? (ping)"
if ping -c1 -W1 "$OBJETIVO" >/dev/null 2>&1; then
  echo "    -> host ACTIVO"
else
  echo "    -> sin respuesta, abortando"; exit 1
fi

echo "[2] Buscando TODOS los puertos abiertos (-p-, sin DNS)"
ABIERTOS=$(nmap -n -T4 --open -p- "$OBJETIVO" 2>/dev/null \
           | grep -oP '^[0-9]+(?=/tcp\s+open)' | paste -sd, -)
echo "    -> abiertos: ${ABIERTOS:-ninguno}"
[ -z "$ABIERTOS" ] && exit 0

INFORME="recon_${OBJETIVO}.txt"
echo "[3] Servicios + version, y guardando informe en $INFORME"
nmap -n -sV -p "$ABIERTOS" -oN "$INFORME" "$OBJETIVO" 2>/dev/null | grep -E '^[0-9]+/tcp'
echo "[4] Listo. Informe guardado:"
ls -l "$INFORME"
