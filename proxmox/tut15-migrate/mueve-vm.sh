#!/usr/bin/env bash
# mueve-vm.sh — respalda una VM y la restaura como una VM NUEVA, en el disco que elijas.
# Es la vía UNIVERSAL para mover/clonar una máquina entre discos o entre nodos en Proxmox,
# con o sin clúster: el respaldo (vzdump) es portátil, la restauración (qmrestore) decide
# dónde aterriza. Copia el .vma a otro nodo y lanza el restore allí para moverla de nodo.
#
#   mueve-vm.sh <vmid_origen> <id_nuevo> <storage_backup> <storage_destino>
#   ej:  mueve-vm.sh 100 9500 almacen vmstore
#
# Lo hace en caliente (modo snapshot): la VM de origen no se apaga.
set -euo pipefail

SRC="${1:?vmid de origen}"
NEW="${2:?id nuevo para la VM restaurada}"
BSTORE="${3:?almacenamiento donde guardar la copia (content: backup)}"
DSTORE="${4:?almacenamiento de destino del disco restaurado}"

command -v qm >/dev/null      || { echo "esto se ejecuta en un nodo Proxmox"; exit 1; }
qm status "$SRC" >/dev/null   || { echo "la VM $SRC no existe"; exit 1; }
qm status "$NEW" >/dev/null 2>&1 && { echo "el id $NEW ya está en uso, elige otro"; exit 1; }

echo "==> 1/2  respaldo en caliente de la VM $SRC en '$BSTORE' (modo snapshot)"
vzdump "$SRC" --storage "$BSTORE" --mode snapshot --compress zstd

# localiza el .vma recién creado para esta VM (el más reciente)
DUMP=$(awk -v id="$BSTORE" '$1==id":"||$1=="dir:"id{f=1} f&&/path /{print $2;exit}' /etc/pve/storage.cfg)/dump
ARCHIVE=$(ls -1t "$DUMP"/vzdump-qemu-"$SRC"-*.vma.* 2>/dev/null | grep -v '\.notes$' | head -1)
[ -n "$ARCHIVE" ] || { echo "no encuentro el fichero de copia en $DUMP"; exit 1; }
echo "    copia -> $ARCHIVE"

echo "==> 2/2  restauración como VM $NEW en el almacenamiento '$DSTORE'"
qmrestore "$ARCHIVE" "$NEW" --storage "$DSTORE"

echo "==> listo: VM $NEW restaurada en '$DSTORE'. Arráncala con:  qm start $NEW"
qm config "$NEW" | grep -E '^(name|scsi0|virtio0|ide0|boot):' || true
