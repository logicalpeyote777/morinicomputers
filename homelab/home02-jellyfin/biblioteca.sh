#!/bin/bash
# Crea las dos bibliotecas por API. El token sale de autenticarse como el
# administrador que acabamos de crear; caduca, asi que se pide cada vez.
set -e
J=http://10.10.10.10:8096
TOK=$(curl -s -X POST "$J/Users/AuthenticateByName" \
  -H 'Content-Type: application/json' \
  -H 'Authorization: MediaBrowser Client="cli", Device="homelab", DeviceId="homelab-cli", Version="1.0"' \
  -d '{"Username":"luca","Pw":"clave-falsa-de-lab"}' | jq -r .AccessToken)

add() {  # add <nombre> <tipo> <ruta dentro del contenedor>
  curl -s -X POST "$J/Library/VirtualFolders?name=$1&collectionType=$2&refreshLibrary=true" \
    -H "Authorization: MediaBrowser Token=$TOK" -H 'Content-Type: application/json' \
    -d "{\"LibraryOptions\":{\"PathInfos\":[{\"Path\":\"$3\"}]}}" -o /dev/null -w "$1 -> HTTP %{http_code}\n"
}
add Peliculas movies  /media/peliculas
add Series    tvshows /media/series

echo "$TOK" > ~/.jftok      # lo reutilizamos en los siguientes pasos
