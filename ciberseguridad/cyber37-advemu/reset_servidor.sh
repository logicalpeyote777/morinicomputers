#!/bin/bash
# reset_servidor.sh - deja el servidor como estaba antes del ataque, para poder repetir
# la MISMA cadena y comparar la cobertura antes/despues. github.com/logicalpeyote777/morinicomputers
set -u
userdel -r soporte-tec 2>/dev/null
rm -f /etc/cron.d/backup-sys /tmp/.datos.tar.gz
systemctl disable --now sys-update.service 2>/dev/null
rm -f /etc/systemd/system/sys-update.service; systemctl daemon-reload 2>/dev/null
sed -i '/atacante@kali/d' /root/.ssh/authorized_keys 2>/dev/null
echo "servidor limpio:"
printf '  cuenta soporte-tec: %s\n' "$(id soporte-tec 2>/dev/null || echo no existe)"
printf '  cron backup-sys:    %s\n' "$(ls /etc/cron.d/backup-sys 2>/dev/null || echo no existe)"
printf '  servicio sys-update:%s\n' "$(ls /etc/systemd/system/sys-update.service 2>/dev/null || echo ' no existe')"
printf '  clave del atacante: %s\n' "$(grep -c atacante@kali /root/.ssh/authorized_keys 2>/dev/null || echo 0)"
