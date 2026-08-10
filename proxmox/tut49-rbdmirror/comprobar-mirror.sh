#!/bin/bash
# comprobar-mirror.sh - salud del espejo RBD entre dos clusteres Proxmox.
# Uso: ./comprobar-mirror.sh <pool>        github.com/logicalpeyote777/morinicomputers
POOL="${1:-cephdr}"
MAX_RPO=300   # segundos: si el ultimo snapshot es mas viejo, es un AVISO

echo "== demonio rbd-mirror"
systemctl is-active 'ceph-rbd-mirror@*' | tr '\n' ' '; echo

echo "== pool $POOL"
rbd mirror pool info "$POOL" | sed 's/^/   /'

echo "== pareja (peer)"
rbd mirror pool info "$POOL" --all | grep -E 'UUID|Name|Mirror UUID|Direction' | sed 's/^/   /'

echo "== imagenes"
rbd mirror pool status "$POOL" --verbose | grep -E '^[a-z]|state:|description:|last_update' | sed 's/^/   /'

echo "== RPO (edad del ultimo snapshot de espejo)"
AHORA=$(date +%s)
for img in $(rbd ls "$POOL"); do
  ts=$(rbd mirror image status "$POOL/$img" 2>/dev/null | grep -oP 'last_update: \K.*')
  [ -z "$ts" ] && { echo "   $img: sin estado (¿espejo desactivado?)"; continue; }
  edad=$(( AHORA - $(date -d "$ts" +%s 2>/dev/null || echo "$AHORA") ))
  if [ "$edad" -gt "$MAX_RPO" ]; then echo "   $img: $edad s  <-- AVISO (> $MAX_RPO s)"
  else echo "   $img: $edad s  OK"; fi
done
