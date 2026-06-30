#!/usr/bin/env bash
# pve-update.sh — actualización SEGURA de Proxmox VE para homelab (Morini Computers).
#
# Hace, en el orden correcto, lo que debe hacer un sysadmin para actualizar sin sustos:
#   1) refresca los índices de los repositorios (apt update)
#   2) te enseña QUÉ se va a actualizar antes de tocar nada
#   3) actualiza con 'full-upgrade' (NUNCA 'upgrade': ese retiene kernels y te deja a medias)
#   4) limpia dependencias huérfanas (autoremove --purge)
#   5) lista los kernels instalados (recuerda dejar solo los 2 últimos: el /boot es pequeño)
#   6) comprueba si hace falta reiniciar (kernel nuevo) y TE AVISA — nunca reinicia solo
#
# Requisito previo: repos bien puestos (rama gratuita 'pve-no-subscription', sin el
# repo 'enterprise' activo sin licencia). Pensado para ejecutarse como root.
set -euo pipefail

echo "== Proxmox: $(pveversion | head -1) =="

echo "-- 1) refrescar índices de repositorios --"
apt-get update -qq

echo "-- 2) ¿qué hay para actualizar? (míralo ANTES) --"
apt list --upgradable 2>/dev/null | grep -v '^Listando' || true

echo "-- 3) actualización completa (full-upgrade: la correcta en Proxmox) --"
DEBIAN_FRONTEND=noninteractive apt-get -y full-upgrade

echo "-- 4) limpiar dependencias huérfanas --"
apt-get -y --purge autoremove

echo "-- 5) kernels instalados (deja solo los 2 últimos; borra viejos con 'kernel remove') --"
proxmox-boot-tool kernel list 2>/dev/null || true

echo "-- 6) ¿hace falta reiniciar? (¿ha entrado un kernel nuevo?) --"
run="$(uname -r)"
new="$(ls -1 /boot/vmlinuz-*-pve 2>/dev/null | sed 's#.*/vmlinuz-##' | sort -V | tail -1)"
if [ -n "$new" ] && [ "$run" != "$new" ]; then
  echo "!! REINICIO recomendado: corriendo $run, pero instalado $new."
  echo "   Reinicia a tu ritmo (avisa a las VMs y elige un momento tranquilo)."
else
  echo "OK: ya estás en el kernel más reciente ($run). No hace falta reiniciar."
fi
