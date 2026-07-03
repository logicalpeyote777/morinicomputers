#!/bin/bash
# anadir-cliente.sh <nombre> — da de alta un dispositivo nuevo en la VPN:
#   1) genera su par de claves        3) escribe su fichero de configuración
#   2) lo añade como [Peer] al túnel  4) imprime el QR para el móvil
set -eu
NOMBRE="${1:?uso: anadir-cliente.sh <nombre>}"
DIR=/etc/wireguard; CONF=$DIR/wg0.conf
ENDPOINT="10.99.0.210:51820"   # <- en tu casa: tu IP pública o dominio DDNS

# siguiente IP libre del rango 10.9.0.x
ULT=$(grep -oP 'AllowedIPs = 10\.9\.0\.\K[0-9]+' $CONF | sort -n | tail -1)
IP="10.9.0.$(( ${ULT:-1} + 1 ))"

umask 077
wg genkey | tee $DIR/$NOMBRE.key | wg pubkey > $DIR/$NOMBRE.pub

cat >> $CONF <<EOF

[Peer]
# $NOMBRE
PublicKey = $(cat $DIR/$NOMBRE.pub)
AllowedIPs = $IP/32
EOF

cat > $DIR/$NOMBRE.conf <<EOF
[Interface]
PrivateKey = $(cat $DIR/$NOMBRE.key)
Address = $IP/24

[Peer]
PublicKey = $(cat $DIR/server.pub)
Endpoint = $ENDPOINT
AllowedIPs = 10.9.0.0/24, 192.168.1.0/24
PersistentKeepalive = 25
EOF

# recarga el túnel SIN cortar a los clientes conectados
wg syncconf wg0 <(wg-quick strip wg0)
echo "== cliente $NOMBRE dado de alta con IP $IP =="
qrencode -t ansiutf8 < $DIR/$NOMBRE.conf
