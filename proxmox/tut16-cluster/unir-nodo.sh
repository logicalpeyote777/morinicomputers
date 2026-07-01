#!/bin/bash
# unir-nodo.sh — une ESTE nodo a un clúster Proxmox, con comprobaciones previas.
# Morini Computers · tutorial «Crea un clúster Proxmox de varios nodos».
#
# Uso:   ./unir-nodo.sh <IP-del-nodo-primario>
# Se ejecuta EN EL NODO QUE SE UNE. Ese nodo debe estar VACÍO (sin VMs ni CTs):
# al unirse, su /etc/pve se reemplaza por el del clúster y perdería sus definiciones.
set -euo pipefail
PRIMARIO="${1:?Uso: unir-nodo.sh <IP-del-nodo-primario>}"

echo "== 1/4  el nombre del nodo resuelve a una IP real (no loopback) =="
IP="$(hostname --ip-address 2>/dev/null | awk '{print $1}')"
case "$IP" in
  127.*|"") echo "   ERROR: '$(hostname)' resuelve a '$IP'. Arregla /etc/hosts."; exit 1 ;;
esac
echo "   OK  $(hostname) -> $IP"

echo "== 2/4  reloj sincronizado (corosync lo exige) =="
if timedatectl show -p NTPSynchronized --value 2>/dev/null | grep -qx yes; then
  echo "   OK  hora sincronizada"
else
  echo "   ERROR: la hora no está sincronizada. Activa chrony/systemd-timesyncd."; exit 1
fi

echo "== 3/4  el nodo está VACÍO (unirse reemplaza su configuración) =="
GUESTS="$( (qm list 2>/dev/null | awk 'NR>1{print "VM "$1}'; pct list 2>/dev/null | awk 'NR>1{print "CT "$1}') )"
if [ -z "$GUESTS" ]; then
  echo "   OK  sin máquinas ni contenedores"
else
  echo "   ERROR: este nodo ya contiene guests. Respalda (vzdump), bórralos y reintenta:"
  echo "$GUESTS"; exit 1
fi

echo "== 4/4  alcanzo al nodo primario $PRIMARIO por SSH =="
if ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new "root@$PRIMARIO" pvecm status >/dev/null 2>&1; then
  echo "   OK  primario accesible y ya en clúster"
else
  echo "   ERROR: no llego a root@$PRIMARIO o ese nodo no tiene clúster creado."; exit 1
fi

echo "== todo en orden -> uniendo este nodo al clúster =="
pvecm add "$PRIMARIO"
echo "== hecho. Verifica con:  pvecm status  y  pvecm nodes =="
