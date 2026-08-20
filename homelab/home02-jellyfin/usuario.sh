#!/bin/bash
# Un usuario por persona de la casa, y NINGUNO con permisos de mas.
# 'invitado' puede ver, pero no descargar, no borrar, dos sesiones a la vez
# y un tope de 4 Mbps cuando entre desde fuera de casa.
# Ojo: la API de Jellyfin NO acepta cambios parciales. Se pide la politica entera,
# se le cambian los campos con jq y se devuelve entera. Misma tecnica en todo Jellyfin.
set -e
J=http://10.10.10.10:8096
TOK=$(cat ~/.jftok)
AUTH="Authorization: MediaBrowser Token=$TOK"

ID=$(curl -s -X POST "$J/Users/New" -H "$AUTH" -H 'Content-Type: application/json' \
      -d '{"Name":"invitado","Password":"otra-clave-falsa"}' | jq -r .Id)
echo "usuario 'invitado' creado con id $ID"

curl -s "$J/Users/$ID" -H "$AUTH" | jq '.Policy
      | .EnableContentDownloading  = false
      | .EnableContentDeletion     = false
      | .MaxActiveSessions         = 2
      | .RemoteClientBitrateLimit  = 4000000' \
| curl -s -X POST "$J/Users/$ID/Policy" -H "$AUTH" -H 'Content-Type: application/json' \
      -d @- -o /dev/null -w "politica aplicada: HTTP %{http_code}\n"

curl -s "$J/Users" -H "$AUTH" | jq -r '.[] | .Name
      + "   admin=" + (.Policy.IsAdministrator|tostring)
      + "   descargas=" + (.Policy.EnableContentDownloading|tostring)
      + "   sesiones=" + (.Policy.MaxActiveSessions|tostring)
      + "   tope_remoto=" + (.Policy.RemoteClientBitrateLimit|tostring)'
