#!/bin/bash
# respaldo-cluster.sh — copia de seguridad de la CONFIGURACIÓN de un clúster Proxmox.
# Morini Computers · tutorial «Disaster recovery del clúster Proxmox».
# Lo que salva: lo que NO está en tus copias de VMs y sin lo cual no puedes reconstruir el clúster.
# Uso:  ./respaldo-cluster.sh          (ponlo en cron, tarda menos de 2 segundos)
set -euo pipefail

DESTINO_LOCAL=/root/dr/respaldos          # copia en el nodo
DESTINO_FUERA=/mnt/pve/nfs-ha/dr          # copia FUERA del nodo (NAS): esta es la que te salva
FECHA=$(date +%F-%H%M)
PAQUETE="$DESTINO_LOCAL/$(hostname)-$FECHA.tar.gz"
mkdir -p "$DESTINO_LOCAL" "$DESTINO_FUERA"

# /etc/pve es pmxcfs: la configuración VIVA del clúster (VMs, usuarios, storages, firewall).
# config.db es esa misma base de datos EN DISCO: de aquí se resucita un clúster muerto del todo.
echo ">> empaquetando la configuración del clúster..."
tar czf "$PAQUETE" \
    /etc/pve \
    /etc/corosync/corosync.conf \
    /etc/network/interfaces \
    /etc/hosts \
    /etc/passwd /etc/shadow \
    /var/lib/pve-cluster/config.db 2>/dev/null

# Una copia que vive en la máquina que se va a morir NO es una copia.
echo ">> sacando la copia fuera del nodo..."
cp "$PAQUETE" "$DESTINO_FUERA/"

# Rotación: nos quedamos con los 14 últimos respaldos (ocupan kilobytes).
ls -1t "$DESTINO_LOCAL"/*.tar.gz | tail -n +15 | xargs -r rm --

echo ">> LISTO: $PAQUETE  ($(du -h "$PAQUETE" | cut -f1))"
echo ">>        copia fuera del nodo en $DESTINO_FUERA"
