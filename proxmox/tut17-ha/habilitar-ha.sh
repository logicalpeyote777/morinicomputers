#!/bin/bash
# habilitar-ha.sh — pone una VM bajo ALTA DISPONIBILIDAD en Proxmox, bien hecho.
# Morini Computers · tutorial «Alta disponibilidad en Proxmox (ha-manager)».
#
# Uso:   ./habilitar-ha.sh <vmid> <grupo> <nodo_preferente> <nodo_secundario>
# Ej.:   ./habilitar-ha.sh 200 ha-grp pve-a pve-b
#
# Comprueba ANTES de tocar nada:
#   1) el clúster tiene quórum (idealmente reforzado con un QDevice),
#   2) el DISCO de la VM está en almacenamiento COMPARTIDO  <-- sin esto NO hay failover.
# Luego crea/ajusta un HA group con prioridades y añade la VM al gestor.
set -euo pipefail
VMID="${1:?Uso: habilitar-ha.sh <vmid> <grupo> <nodo_pref> <nodo_sec>}"
GRP="${2:-ha-grp}"
PREF="${3:?falta el nodo preferente}"
SEC="${4:?falta el nodo secundario}"

# ¿el almacenamiento es compartido (accesible desde todos los nodos)?
es_compartido() {
  local s="$1" j
  j="$(pvesh get "/storage/$s" --output-format json 2>/dev/null)"
  # marcado explícito shared:1 (lo que Proxmox pone a NFS/CIFS/Ceph/iSCSI...)
  echo "$j" | grep -q '"shared":1' && return 0
  # respaldo por tipo, por si acaso
  case "$(echo "$j" | grep -oP '"type":"\K[^"]+')" in
    nfs|cifs|glusterfs|cephfs|rbd|iscsi|iscsidirect|zfs) return 0;; *) return 1;;
  esac
}

echo "== 1/3  el clúster tiene quórum =="
pvecm status | grep -q 'Quorate: *Yes' || { echo "   ERROR: el clúster NO tiene quórum. Aborto."; exit 1; }
echo "   OK  clúster con quórum"

echo "== 2/3  el disco de la VM $VMID está en almacenamiento COMPARTIDO =="
DISK_LINE="$(qm config "$VMID" | grep -E '^(scsi|virtio|sata|ide)[0-9]+:' | grep -v 'media=cdrom' | head -1)"
[ -n "$DISK_LINE" ] || { echo "   ERROR: la VM $VMID no tiene disco. Aborto."; exit 2; }
STORE="$(echo "$DISK_LINE" | sed -E 's/^[a-z]+[0-9]+:[[:space:]]*//' | cut -d: -f1)"
if es_compartido "$STORE"; then
  echo "   OK  disco en '$STORE' (compartido) -> podrá arrancar en otro nodo"
else
  echo "   ERROR: el disco está en '$STORE', que NO es compartido."
  echo "          Sin disco compartido la VM no puede revivir en otro nodo. Aborto."
  exit 3
fi

echo "== 3/3  grupo de HA '$GRP' con prioridades + alta de la VM en el gestor =="
# prioridad alta al preferente, baja al secundario: la VM prefiere PREF y huye a SEC
if ha-manager groupadd "$GRP" -nodes "${PREF}:100,${SEC}:50" -nofailback 0 2>/dev/null; then
  echo "   grupo '$GRP' creado (${PREF}:100, ${SEC}:50)"
else
  ha-manager groupset "$GRP" -nodes "${PREF}:100,${SEC}:50" -nofailback 0
  echo "   grupo '$GRP' actualizado (${PREF}:100, ${SEC}:50)"
fi
ha-manager add "vm:${VMID}" --group "$GRP" --state started --max_restart 3 --max_relocate 3
echo
echo "== hecho: la VM $VMID ya está gestionada por alta disponibilidad =="
ha-manager status | grep -E "master|vm:${VMID}" || true
