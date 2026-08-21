#!/bin/bash
# aviso.sh — smartd nos llama AQUI cuando un disco empieza a fallar.
# No hay que configurar ningun servidor de correo: smartd exporta todo lo que
# necesitamos en variables de entorno y nosotros decidimos a donde va el aviso.
LOG=/home/homelab/lab/smart/aviso.log

DEV="$SMARTD_DEVICESTRING"          # /dev/sdb
TIPO="$SMARTD_FAILTYPE"             # TestEmail / FailedHealthCheck / Currentpendingsector...
MSG="$SMARTD_MESSAGE"               # el texto que ha generado smartd

printf '[%s] %-9s %-24s %s\n' "$(date '+%F %T')" "$DEV" "$TIPO" "$MSG" >> "$LOG"
logger -t aviso-disco "$DEV $TIPO: $MSG"

# Y aqui va TU canal real. Descomenta el que uses:
# curl -s -m 10 -d "chat_id=$CHAT" --data-urlencode "text=DISCO $DEV: $MSG" \
#      https://api.telegram.org/bot$TOKEN/sendMessage >/dev/null
# curl -s -m 10 -H 'Content-Type: application/json' \
#      -d "{\"text\":\"DISCO $DEV: $MSG\"}" "$WEBHOOK" >/dev/null
exit 0
