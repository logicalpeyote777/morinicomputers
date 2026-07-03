#!/bin/bash
# Comandos del tutorial «Acceso remoto a Proxmox: VPN WireGuard en un LXC» (tut28).
# Se ejecutan UNO A UNO en el nodo Proxmox / dentro del contenedor. No es un instalador ciego.

# --- 1) el contenedor (en el nodo Proxmox; ajusta storage/red a tu entorno) ---
pct create 210 local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst \
  --hostname vpn-wg --unprivileged 1 --memory 256 --cores 1 --rootfs local-lvm:3 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.1.210/24,gw=192.168.1.1 \
  --nameserver 9.9.9.9 --start 1

# --- 2) dentro del contenedor: pct enter 210 ---
apt-get update
# OJO: sin --no-install-recommends, el metapaquete "wireguard" arrastra un kernel entero
apt-get install -y --no-install-recommends wireguard-tools qrencode iptables

# --- 3) claves (privada+publica por cada extremo) ---
cd /etc/wireguard
umask 077
wg genkey | tee server.key   | wg pubkey > server.pub
wg genkey | tee portatil.key | wg pubkey > portatil.pub

# --- 4) /etc/wireguard/wg0.conf del SERVIDOR ---
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.9.0.1/24
ListenPort = 51820
PrivateKey = $(cat /etc/wireguard/server.key)
PostUp = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
# portatil
PublicKey = $(cat /etc/wireguard/portatil.pub)
AllowedIPs = 10.9.0.2/32
EOF

# --- 5) reenvio de paquetes (el contenedor hace de router) ---
sysctl -w net.ipv4.ip_forward=1
echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/99-wireguard.conf

# --- 6) arrancar (ahora y en cada reinicio) ---
systemctl enable --now wg-quick@wg0
wg
ss -ulnp | grep 51820

# Si wg-quick falla con «Unknown device type» / «RTNETLINK answers»:
# el modulo del kernel se carga en el HOST Proxmox, NO en el contenedor:
#   modprobe wireguard
#   echo wireguard > /etc/modules-load.d/wireguard.conf

# --- 7) cliente (portatil/movil): fichero + QR ---
cat > /etc/wireguard/portatil.conf <<EOF
[Interface]
PrivateKey = $(cat /etc/wireguard/portatil.key)
Address = 10.9.0.2/24

[Peer]
PublicKey = $(cat /etc/wireguard/server.pub)
Endpoint = TU_IP_PUBLICA_O_DDNS:51820
AllowedIPs = 10.9.0.0/24, 192.168.1.0/24
PersistentKeepalive = 25
EOF
qrencode -t ansiutf8 < /etc/wireguard/portatil.conf

# En tu router: reenvia SOLO el puerto UDP 51820 hacia la IP del contenedor.
# El 8006 (interfaz web) queda CERRADO a internet.
