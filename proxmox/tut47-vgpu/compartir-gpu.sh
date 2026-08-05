#!/bin/bash
# compartir-gpu.sh <CTID> — da el nodo de render del host a un contenedor LXC
# (no privilegiado) y le deja el driver VA-API correcto para la GPU que hay.
# Idempotente: se puede lanzar varias veces.
set -eu

CT="${1:?uso: compartir-gpu.sh <CTID>}"
NODE=/dev/dri/renderD128

[ -e "$NODE" ] || { echo "ERROR: no existe $NODE (¿el host tiene GPU y el driver cargado?)"; exit 1; }

# el gid del grupo 'render' del HOST: sin esto el contenedor ve el fichero pero no puede abrirlo
GID=$(getent group render | cut -d: -f3)
[ -n "$GID" ] || { echo "ERROR: no existe el grupo 'render' en el host"; exit 1; }
echo ">> nodo de render $NODE, grupo render gid=$GID"

pct set "$CT" --dev0 "$NODE,gid=$GID"
pct config "$CT" | grep -E "dev0|unprivileged"

# Driver VA-API: iHD es el moderno (Intel Gen 11+), i965 el clasico (Gen 6-9).
# Poner el que no toca da "vaInitialize failed" y parece que la GPU no esta.
GEN_LEGACY=$(lspci -nn | grep -ci "Core Processor Family Integrated Graphics\|HD Graphics [45][0-9][0-9]\|2nd Generation\|3rd Generation")
if [ "$GEN_LEGACY" -gt 0 ]; then
  DRV=i965-va-driver; NAME=i965; OTHER=intel-media-va-driver
else
  DRV=intel-media-va-driver; NAME=iHD; OTHER=i965-va-driver
fi
echo ">> driver VA-API elegido: $NAME ($DRV)"

pct exec "$CT" -- bash -c "
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get purge -y -qq $OTHER 2>/dev/null || true
  apt-get install -y -qq $DRV vainfo ffmpeg
  echo 'LIBVA_DRIVER_NAME=$NAME' >> /etc/environment
"

echo ">> comprobacion dentro del contenedor:"
pct exec "$CT" -- vainfo --display drm --device "$NODE" 2>/dev/null | head -14
