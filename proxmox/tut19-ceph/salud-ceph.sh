#!/bin/bash
# salud-ceph.sh — foto rápida de la salud de un clúster Ceph en Proxmox.
# Solo lectura (ceph -s + osd tree + df): seguro de ejecutar en producción.
# Tutorial: «Ceph en Proxmox: almacenamiento sin cabina cara» — Morini Computers (YouTube).
set -u
echo "====== ESTADO GENERAL ======"; ceph -s
echo; echo "====== OSD / DISCOS ======"; ceph osd tree
echo; echo "====== ESPACIO (usado / libre) ======"; ceph df
