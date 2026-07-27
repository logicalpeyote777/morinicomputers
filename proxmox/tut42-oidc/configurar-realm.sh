#!/bin/bash
# Realm "morini" en Keycloak: cliente OIDC para Proxmox + grupos de la empresa.
# Codigo completo: github.com/logicalpeyote777/morinicomputers
set -e
KC=/opt/keycloak/bin/kcadm.sh
PVE=https://192.168.1.29:8006

$KC config credentials --server http://localhost:8080 --realm master \
    --user admin --password "Morini2026!"

# 1) El realm = el directorio de usuarios de la empresa
$KC create realms -s realm=morini -s enabled=true \
    -s displayName="Morini Computers" \
    -s internationalizationEnabled=true -s 'supportedLocales=["es"]' -s defaultLocale=es

# 2) El cliente "proxmox": confidencial, con la URL de retorno de tu servidor
$KC create clients -r morini -s clientId=proxmox -s enabled=true \
    -s publicClient=false -s standardFlowEnabled=true \
    -s "redirectUris=[\"${PVE}/*\"]" -s "webOrigins=[\"+\"]"

CID=$($KC get clients -r morini -q clientId=proxmox --fields id --format csv --noquotes)

# 3) Los grupos: aqui es donde se decide quien puede que en Proxmox
for g in pve-admins pve-operadores pve-auditores; do
    $KC create groups -r morini -s name=$g
done

# 4) El mapeador: mete la lista de grupos dentro del token que recibe Proxmox
$KC create clients/$CID/protocol-mappers/models -r morini \
    -s name=grupos -s protocol=openid-connect \
    -s protocolMapper=oidc-group-membership-mapper \
    -s "config.\"claim.name\"=groups" \
    -s "config.\"full.path\"=true" \
    -s "config.\"id.token.claim\"=true" \
    -s "config.\"access.token.claim\"=true" \
    -s "config.\"userinfo.token.claim\"=true"

echo
echo "CLIENT_ID     = proxmox"
echo -n "CLIENT_SECRET = "
$KC get clients/$CID/client-secret -r morini --fields value --format csv --noquotes
