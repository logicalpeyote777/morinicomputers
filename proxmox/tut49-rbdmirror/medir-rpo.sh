#!/bin/bash
# medir-rpo.sh - mide el RPO REAL de un espejo RBD en modo snapshot.
# Escribe una marca dentro de la VM en la sede primaria, fuerza un snapshot de
# espejo y cronometra hasta que ese snapshot ha llegado a ESTA sede.
# Uso: ./medir-rpo.sh          github.com/logicalpeyote777/morinicomputers
IMG=cephdr/vm-100-disk-0
VM=root@10.50.0.100          # la VM de produccion, en la sede primaria

sello() { rbd mirror image status $IMG | grep -oP 'remote_snapshot_timestamp":\K[0-9]+'; }

ANTES=$(sello); T0=$(date +%s)
echo "sello remoto ANTES: $ANTES"

ssh pve-mad "ssh -o StrictHostKeyChecking=no $VM 'date +%F_%T | tee /etc/marca-madrid.txt; sync'"
ssh pve-mad "rbd mirror image snapshot $IMG"

until [ "$(sello)" != "$ANTES" ]; do
  sleep 1
  [ $(( $(date +%s) - T0 )) -gt 120 ] && { echo "TIMEOUT: el espejo no ha llegado"; exit 1; }
done

echo "sello remoto AHORA: $(sello)"
echo "RPO REAL: $(( $(date +%s) - T0 )) segundos"
