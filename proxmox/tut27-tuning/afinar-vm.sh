#!/bin/bash
# afinar-vm.sh <vmid> — aplica los 4 ajustes de rendimiento a una VM de Proxmox:
#   1) cpu host                     (la VM ve tu procesador real: AES-NI, AVX...)
#   2) disco virtio-scsi optimizado (iothread + ssd + discard + caché writeback)
#   3) red virtio                   (paravirtual; conserva la MAC actual)
#   4) ballooning                   (memoria dinámica: mínimo = mitad de la RAM)
# Después, reinicia la VM para aplicar los cambios.
#
# Ojo (matices de profesional):
#   - cpu host ata la VM a ese modelo de CPU: en un clúster con procesadores
#     DISTINTOS usa un modelo intermedio (p. ej. x86-64-v2-AES) para poder migrar.
#   - cache=writeback usa la RAM del servidor como caché de escritura: recomendable
#     solo con SAI/UPS detrás. Si no, quita esa opción.
set -eu
VMID="${1:?uso: afinar-vm.sh <vmid>}"
CFG=$(qm config "$VMID")

qm set "$VMID" --cpu host
qm set "$VMID" --scsihw virtio-scsi-single

VOL=$(echo "$CFG" | awk -F': ' '/^scsi0:/{print $2}' | cut -d, -f1)
qm set "$VMID" --scsi0 "$VOL,iothread=1,ssd=1,discard=on,cache=writeback"

MAC=$(echo "$CFG" | grep '^net0:' | grep -oE '([0-9A-F]{2}:){5}[0-9A-F]{2}')
BR=$(echo "$CFG"  | grep '^net0:' | grep -oP '(?<=bridge=)[^,]+')
qm set "$VMID" --net0 "virtio=$MAC,bridge=$BR"

MEM=$(echo "$CFG" | awk '/^memory:/{print $2}')
qm set "$VMID" --balloon "$((MEM/2))"

echo "VM $VMID afinada. Reiníciala para aplicar: qm shutdown $VMID && qm start $VMID"
