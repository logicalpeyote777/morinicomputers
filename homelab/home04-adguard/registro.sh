#!/bin/bash
# El registro de consultas: QUIEN pregunto QUE, y si se lo hemos cortado.
set -u
printf '\n  %-18s %-40s %s\n' "EQUIPO" "DOMINIO" "RESULTADO"
printf '  %-18s %-40s %s\n' "------------------" "----------------------------------------" "---------"
curl -s -u homelab:clave-falsa-de-laboratorio "http://10.10.10.10:8090/control/querylog?limit=16" \
| jq -r '.data[] | [ (if (.client_info.name // "") == "" then .client else .client_info.name end),
                     .question.name,
                     (if (.reason|startswith("Filtered")) then "BLOQUEADO" else "permitido" end) ] | @tsv' \
| awk -F'\t' '{printf "  %-18s %-40s %s\n", $1, $2, $3}'
echo
