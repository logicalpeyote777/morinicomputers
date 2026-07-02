#!/bin/bash
# replicar-vm.sh <vmid> <nodo-destino> <cada-min>
# Crea (o recrea, idempotente) la replicación ZFS de una VM hacia otro nodo del clúster
# y lanza la primera sincronización. Requiere que el disco de la VM viva en un storage ZFS.
set -euo pipefail
VMID="${1:?uso: replicar-vm.sh <vmid> <nodo-destino> <cada-min>}"
DEST="${2:?falta el nodo destino}"
MIN="${3:-15}"
JOB="${VMID}-0"
echo "==> replico la VM $VMID hacia $DEST cada $MIN min (job $JOB)"
pvesr delete "$JOB" --force 2>/dev/null || true    # idempotente: si ya existe, lo recreo limpio
pvesr create-local-job "$JOB" "$DEST" --schedule "*/$MIN"
echo "==> primera sincronización (envío ZFS inicial):"
pvesr run --id "$JOB"
echo "==> estado de las replicaciones:"
pvesr status
