#!/bin/bash
# alertas.sh [n] - las ultimas alertas de Wazuh, una por linea: hora, nivel, regla,
# tecnica ATT&CK y descripcion.  github.com/logicalpeyote777/morinicomputers
jq -Rr 'fromjson? | [.timestamp[11:19], .rule.level, .rule.id, ((.rule.mitre.id // ["-"]) | join(",")),
        .rule.description] | @tsv' /var/ossec/logs/alerts/alerts.json |
  tail -"${1:-8}" | column -t -s "$(printf '\t')"
