#!/bin/bash
# informe-cambios.sh — informe FIRMADO de cambios del nodo Proxmox, para auditoría.
# Fuentes: registro de tareas de Proxmox y registro de acceso de la API (pveproxy).
# Morini Computers · github.com/logicalpeyote777/morinicomputers
set -eu
DIAS="${1:-7}"
DEST=/root/audit/informes; mkdir -p "$DEST"
INF="$DEST/cambios-$(date +%F).txt"
DESDE=$(date -d "-$DIAS days" +%s)

# tareas que CAMBIAN algo (lo demás son consultas y no van al informe)
CAMBIOS='qmstart|qmstop|qmshutdown|qmreset|qmdestroy|qmconfig|qmsnapshot|qmrollback|qmmigrate|vzstart|vzstop|vzdestroy|vzcreate|vzdump|acl-update|useradd|userdel'

{
  echo "INFORME DE CAMBIOS · nodo $(hostname) · Morini Computers S.L."
  echo "Periodo: $(date -d "-$DIAS days" +%F) -> $(date +%F)   Generado: $(date '+%F %T %Z')"
  echo "--------------------------------------------------------------------------------------"
  printf '%-19s  %-24s  %-11s  %-7s  %s\n' "FECHA Y HORA" "USUARIO" "ACCIÓN" "OBJETO" "RESULTADO"
  n=0
  while read -r upid resto; do
    IFS=: read -r _ _ _ _ hexini tipo objeto usuario _ <<<"$upid"
    [[ "$tipo" =~ ^($CAMBIOS)$ ]] || continue
    ini=$((16#$hexini)); (( ini >= DESDE )) || continue
    estado="${resto#* }"
    printf '%-19s  %-24s  %-11s  %-7s  %s\n' \
      "$(date -d "@$ini" '+%F %T')" "${usuario:--}" "$tipo" "${objeto:--}" "${estado:0:30}"
    n=$((n+1))
  done < /var/log/pve/tasks/index
  echo "--------------------------------------------------------------------------------------"
  d=días; [ "$DIAS" = 1 ] && d=día
  echo "Total: $n cambios en $DIAS $d"
  echo
  echo "LLAMADAS DE ESCRITURA A LA API (POST/PUT/DELETE), por usuario:"
  awk '/"(POST|PUT|DELETE) /{print "   "$3}' /var/log/pveproxy/access.log | sort | uniq -c | sort -rn | head -8
  echo
  echo "CADENA DE CUSTODIA — huella SHA-256 de las fuentes:"
  sha256sum /var/log/pve/tasks/index /var/log/pveproxy/access.log | sed 's/^/   /'
} > "$INF"

# firma Ed25519: cualquiera con la clave pública puede probar que no se ha tocado
openssl pkeyutl -sign -rawin -inkey /root/audit/auditoria.key -in "$INF" -out "$INF.sig"
echo "informe: $INF"
echo "firma:   $INF.sig"
