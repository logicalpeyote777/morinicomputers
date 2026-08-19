#!/bin/bash
# crear-colector.sh — colector central de logs del clúster, en un LXC.
# systemd-journal-remote recibe el journal de TODOS los nodos por la red.
# Morini Computers · github.com/logicalpeyote777/morinicomputers
set -e
CT=231; IP=192.168.1.231
PLANTILLA=local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst

# 1) contenedor pequeño, sin privilegios, arranca con el nodo
pct create $CT $PLANTILLA --hostname auditoria --unprivileged 1 --onboot 1 \
    --cores 1 --memory 512 --swap 256 --rootfs vmstore:8 \
    --net0 name=eth0,bridge=vmbr0,ip=$IP/24,gw=192.168.1.1 --nameserver 192.168.1.1
pct start $CT; sleep 10

# 2) el receptor
pct exec $CT -- apt-get update -qq
pct exec $CT -- bash -c 'DEBIAN_FRONTEND=noninteractive apt-get install -y -qq systemd-journal-remote'

# 3) OJO: el servicio viene en HTTPS y sin certificados NO arranca. Dentro de la red
#    de gestión escuchamos en HTTP; de cara a internet, certificados obligatorios.
pct exec $CT -- mkdir -p /etc/systemd/system/systemd-journal-remote.service.d
pct exec $CT -- bash -c "cat > /etc/systemd/system/systemd-journal-remote.service.d/http.conf <<EOF
[Service]
ExecStart=
ExecStart=/usr/lib/systemd/systemd-journal-remote --listen-http=-3 --output=/var/log/journal/remote/
EOF"

# 4) un fichero por nodo y tope de disco: el colector nunca llena el contenedor
pct exec $CT -- bash -c "cat > /etc/systemd/journal-remote.conf <<EOF
[Remote]
SplitMode=host
MaxUse=2G
MaxFileSize=128M
EOF"

# 5) journal persistente y arranque
pct exec $CT -- mkdir -p /var/log/journal/remote
pct exec $CT -- chown systemd-journal-remote:systemd-journal /var/log/journal/remote
pct exec $CT -- systemctl daemon-reload
pct exec $CT -- systemctl enable --now systemd-journal-remote.socket
pct exec $CT -- systemctl restart systemd-journal-remote.service
sleep 2
echo "colector: http://$IP:19532  estado: $(pct exec $CT -- systemctl is-active systemd-journal-remote.service)"
