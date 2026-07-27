#!/bin/bash
# cobertura.sh - mide QUE PARTE de una cadena de ataque MITRE ATT&CK ha visto tu Wazuh.
# Uso: ./cobertura.sh [minutos]   (ventana hacia atras; por defecto 15)
# github.com/logicalpeyote777/morinicomputers
set -u
ALERTS=/var/ossec/logs/alerts/alerts.json
MIN="${1:-15}"
SINCE=$(date -u -d "-${MIN} minutes" +%Y-%m-%dT%H:%M:%S)

# tecnica ATT&CK | que hace el atacante | IDs de regla de Wazuh que la delatan
CADENA=(
  "T1078.003|Acceso con credenciales validas (SSH)|5715,5501"
  "T1082|Reconocimiento del sistema|100211"
  "T1087.001|Enumeracion de cuentas locales|100210"
  "T1046|Descubrimiento de servicios de red|100212"
  "T1136.001|Creacion de una cuenta nueva|5902,5901"
  "T1098.004|Clave SSH plantada (authorized_keys)|100220"
  "T1053.003|Persistencia por cron|100221"
  "T1543.002|Persistencia por servicio systemd|100222"
  "T1074.001|Datos empaquetados para robarlos|100213"
  "T1070.003|Borrado del historial de comandos|100214"
)

# alertas de la ventana -> una linea por alerta con su regla y sus tecnicas
VENTANA=$(jq -Rc --arg s "$SINCE" 'fromjson? | select(.timestamp >= $s)
          | {r: .rule.id, m: (.rule.mitre.id // [])}' "$ALERTS")

printf '\n  VENTANA: ultimos %s min   ALERTAS: %s\n\n' "$MIN" "$(echo "$VENTANA" | grep -c .)"
printf '  %-12s %-42s %s\n' "TECNICA" "QUE HIZO EL ATACANTE" "WAZUH"
printf '  %s\n' "------------------------------------------------------------------------"

VISTAS=0
for fila in "${CADENA[@]}"; do
  TEC="${fila%%|*}"; RESTO="${fila#*|}"; DESC="${RESTO%%|*}"; IDS="${RESTO##*|}"
  HIT=""
  echo "$VENTANA" | grep -q "\"$TEC\"" && HIT="ATT&CK"
  for id in ${IDS//,/ }; do
    [ -n "$HIT" ] && break
    echo "$VENTANA" | grep -q "\"r\":\"$id\"" && HIT="regla $id"
  done
  if [ -n "$HIT" ]; then VISTAS=$((VISTAS+1))
    printf '  %-12s %-42s \033[32mDETECTADA\033[0m (%s)\n' "$TEC" "$DESC" "$HIT"
  else
    printf '  %-12s %-42s \033[31mCIEGA\033[0m\n' "$TEC" "$DESC"
  fi
done
printf '\n  COBERTURA DEFENSIVA: %s de %s tecnicas  (%s%%)\n\n' \
       "$VISTAS" "${#CADENA[@]}" "$(( VISTAS * 100 / ${#CADENA[@]} ))"
