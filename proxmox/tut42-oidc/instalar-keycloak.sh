#!/bin/bash
# Keycloak 26 sobre Debian 13 (LXC) — el proveedor de identidad de la empresa.
# Codigo completo: github.com/logicalpeyote777/morinicomputers
set -e
KC=26.7.0
apt-get update -qq
apt-get install -y -qq openjdk-21-jre-headless curl

curl -sSL -o /tmp/kc.tar.gz \
  https://github.com/keycloak/keycloak/releases/download/${KC}/keycloak-${KC}.tar.gz
tar -xzf /tmp/kc.tar.gz -C /opt
ln -sfn /opt/keycloak-${KC} /opt/keycloak
id keycloak >/dev/null 2>&1 || useradd -r -d /opt/keycloak -s /usr/sbin/nologin keycloak
chown -R keycloak: /opt/keycloak-${KC}

cat >/etc/systemd/system/keycloak.service <<EOF
[Unit]
Description=Keycloak SSO
After=network-online.target
[Service]
User=keycloak
Environment=KC_BOOTSTRAP_ADMIN_USERNAME=admin
Environment=KC_BOOTSTRAP_ADMIN_PASSWORD=Morini2026!
ExecStart=/opt/keycloak/bin/kc.sh start-dev --http-host=0.0.0.0 --http-port=8080 \\
          --hostname=http://192.168.1.220:8080
Restart=always
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now keycloak
