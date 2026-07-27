#!/bin/bash
# telemetria.sh - le da OJOS a tu Wazuh. Sin telemetria no hay deteccion posible.
#   1) snoopy: registra CADA comando que se ejecuta en el servidor (via ld.so.preload,
#      funciona tambien donde auditd no esta disponible, p.ej. contenedores y VPS).
#   2) FIM en tiempo real sobre las tres carpetas donde se planta la persistencia:
#      cron, servicios systemd y las claves SSH de root.
# Idempotente: puedes lanzarlo dos veces.  github.com/logicalpeyote777/morinicomputers
set -eu

# --- 1) telemetria de ejecucion ---------------------------------------------
dpkg -s snoopy >/dev/null 2>&1 || apt-get install -y -qq snoopy
grep -q libsnoopy /etc/ld.so.preload 2>/dev/null \
  || echo /usr/lib/x86_64-linux-gnu/libsnoopy.so >> /etc/ld.so.preload

# --- 2) telemetria de ficheros (FIM en tiempo real) -------------------------
CONF=/var/ossec/etc/ossec.conf
if ! grep -q "purple-team-telemetria" $CONF; then
cat >> $CONF <<'EOF'

<!-- purple-team-telemetria -->
<ossec_config>
  <syscheck>
    <directories check_all="yes" realtime="yes" report_changes="yes">/etc/cron.d,/etc/cron.daily</directories>
    <directories check_all="yes" realtime="yes" report_changes="yes">/etc/systemd/system,/root/.ssh</directories>
  </syscheck>
</ossec_config>
EOF
fi

# --- 3) las reglas Sigma traducidas a Wazuh ---------------------------------
install -m 640 -o root -g wazuh /root/purple/local_rules.xml /var/ossec/etc/rules/local_rules.xml

# --- 4) recargar y comprobar ------------------------------------------------
systemctl restart wazuh-manager
sleep 5
echo "snoopy:  $(grep -c snoopy /etc/ld.so.preload) precarga activa"
echo "reglas:  $(grep -c '<rule id=' /var/ossec/etc/rules/local_rules.xml) reglas locales cargadas"
echo "wazuh:   $(/var/ossec/bin/wazuh-control status | grep -c running) procesos en marcha"
