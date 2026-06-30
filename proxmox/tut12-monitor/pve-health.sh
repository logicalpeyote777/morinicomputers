#!/bin/bash
# pve-health.sh — vigilante de salud para Proxmox VE (Morini Computers).
# Consulta las métricas del nodo y la salud SMART de los discos por la API de
# Proxmox; si algún valor supera su umbral, envía una alerta por correo.
# Pensado para cron (p. ej. cada 15 min). Sin dependencias extra.
#   uso:  ./pve-health.sh
#   ajustes:  LOAD_MAX=8 MEM_MAX=90 DISK_MAX=85 ALERT_TO=tu@correo ./pve-health.sh
set -u
NODE="$(hostname)"
LOAD_MAX="${LOAD_MAX:-8}"      # carga (load average 1 min) máxima
MEM_MAX="${MEM_MAX:-90}"       # % de memoria usada máximo
DISK_MAX="${DISK_MAX:-85}"     # % de disco raíz máximo
ALERT_TO="${ALERT_TO:-root}"   # destinatario del aviso

# --- métricas del nodo, en una sola consulta a la API ---
read -r LOAD MEMU MEMT DSKU DSKT < <(pvesh get "/nodes/$NODE/status" --output-format json \
  | python3 -c 'import sys,json;d=json.load(sys.stdin);m=d["memory"];r=d["rootfs"];print(d["loadavg"][0],m["used"],m["total"],r["used"],r["total"])')
MEMP=$(( 100 * MEMU / MEMT ))
DSKP=$(( 100 * DSKU / DSKT ))

ALERTS=""
awk "BEGIN{exit !($LOAD > $LOAD_MAX)}" && ALERTS+="- Carga alta: $LOAD (máx $LOAD_MAX)\n"
[ "$MEMP" -gt "$MEM_MAX" ]  && ALERTS+="- Memoria alta: ${MEMP}% (máx ${MEM_MAX}%)\n"
[ "$DSKP" -gt "$DISK_MAX" ] && ALERTS+="- Disco raíz lleno: ${DSKP}% (máx ${DISK_MAX}%)\n"

# --- salud SMART de cada disco físico ---
while read -r DEV HEALTH; do
  [ "$HEALTH" = "PASSED" ] || ALERTS+="- Disco $DEV con salud '$HEALTH'\n"
done < <(pvesh get "/nodes/$NODE/disks/list" --output-format json \
  | python3 -c 'import sys,json;[print(d["devpath"],d.get("health","?")) for d in json.load(sys.stdin)]')

echo "[$(date '+%F %T')] $NODE  carga=$LOAD  mem=${MEMP}%  disco=${DSKP}%"
if [ -n "$ALERTS" ]; then
  printf "Proxmox '%s' tiene avisos:\n\n%b\n-- pve-health.sh" "$NODE" "$ALERTS" \
    | mail -s "[Proxmox] ALERTA en $NODE" "$ALERT_TO"
  echo ">> ALERTA enviada a $ALERT_TO"
else
  echo ">> todo dentro de límites: nada que reportar"
fi
