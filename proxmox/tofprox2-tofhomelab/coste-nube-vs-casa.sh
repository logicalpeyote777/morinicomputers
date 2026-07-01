#!/bin/bash
# coste-nube-vs-casa.sh — ¿cuánto cuesta la NUBE frente a un SERVIDOR en casa?
# Suma lo que pagas al mes por servicios de nube y lo compara con un mini-PC
# de segunda mano + Proxmox (gratis). Los precios son variables: ajústalos.
#   uso: coste-nube-vs-casa.sh [años] [€/mes nube] [precio PC] [vatios] [€/kWh]
set -u
ANIOS=${1:-3}          # horizonte de comparación
NUBE_MES=${2:-27}      # Drive 2TB + Fotos + copias + VPN + hosting (aprox, €/mes)
PC=${3:-180}           # mini-PC de oficina de 2ª mano (pago único)
VATIOS=${4:-12}        # consumo medio del servidor en reposo
KWH=${5:-0.15}         # precio de la luz (€/kWh)
MESES=$((ANIOS*12))
awk -v a="$ANIOS" -v m="$MESES" -v nm="$NUBE_MES" -v pc="$PC" -v w="$VATIOS" -v k="$KWH" 'BEGIN{
  nube = nm*m;
  luz  = (w/1000)*24*30 * k * m;
  casa = pc + luz;
  printf "  Horizonte: %d años (%d meses)\n\n", a, m;
  printf "  NUBE  (%2d €/mes)              => %6.0f €\n", nm, nube;
  printf "  CASA  PC %d € + luz %.0f €     => %6.0f €\n", pc, luz, casa;
  printf "  ------------------------------------------\n";
  printf "  AHORRAS con tu servidor       => %6.0f €\n", nube-casa;
  printf "  Se amortiza en                => %.1f meses\n", casa/nm;
}'
