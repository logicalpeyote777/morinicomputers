#!/bin/bash
# iommu-grupos.sh — lista cada grupo IOMMU con sus dispositivos.
# Regla de oro: un dispositivo solo se pasa a una VM si su grupo esta LIMPIO
# (el grupo entero viaja junto: dispositivos que no quieres incluir = no pasar).
shopt -s nullglob
for g in /sys/kernel/iommu_groups/*; do
  echo "== grupo ${g##*/} =="
  for d in "$g"/devices/*; do
    echo "   $(lspci -nns "${d##*/}")"
  done
done
