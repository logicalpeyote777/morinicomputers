#!/bin/bash
# Alta de un empleado: se crea UNA vez en Keycloak y ya entra en Proxmox.
# uso: ./alta-usuario.sh <usuario> "<Nombre Apellidos>" <grupo>
# Codigo completo: github.com/logicalpeyote777/morinicomputers
set -e
USUARIO=$1; NOMBRE=$2; GRUPO=$3
KC=/opt/keycloak/bin/kcadm.sh
PASS_INICIAL="Morini2026!"

$KC config credentials --server http://localhost:8080 --realm master \
    --user admin --password "Morini2026!" >/dev/null

$KC create users -r morini -s username="$USUARIO" -s enabled=true \
    -s firstName="${NOMBRE%% *}" -s lastName="${NOMBRE#* }" \
    -s email="$USUARIO@morini.local" -s emailVerified=true

# Contrasena TEMPORAL: el empleado la cambia en su primer inicio de sesion
$KC set-password -r morini --username "$USUARIO" \
    --new-password "$PASS_INICIAL" --temporary

UID_=$($KC get users -r morini -q username="$USUARIO" --fields id --format csv --noquotes)
GID_=$($KC get groups -r morini -q search="$GRUPO" --fields id --format csv --noquotes)
$KC update "users/$UID_/groups/$GID_" -r morini -n

echo "OK  $USUARIO -> grupo $GRUPO  (clave temporal: $PASS_INICIAL)"
