#!/bin/bash
# comprobar-vgpu.sh — ¿este servidor soporta vGPU / SR-IOV de verdad?
# Solo lee el kernel: no instala nada y no toca nada.
set -u

echo "=== 1. la tarjeta y el driver que la lleva ==="
lspci -nnk | grep -A3 -i vga

echo
echo "=== 2. mediated devices (mdev) — la vía de NVIDIA vGPU ==="
ls /sys/bus/pci/devices/*/mdev_supported_types 2>&1
command -v mdevctl >/dev/null && mdevctl types
echo "mdev activos: $(ls /sys/bus/mdev/devices 2>/dev/null | wc -l)"

echo
echo "=== 3. SR-IOV y el IOMMU — sin esto no hay nada que hacer ==="
ls /sys/bus/pci/devices/*/sriov_totalvfs 2>&1
IOMMU=$(ls /sys/kernel/iommu_groups 2>/dev/null | wc -l)
echo "grupos IOMMU: $IOMMU"
echo "lineas DMAR en el arranque: $(dmesg | grep -ci DMAR)"

echo
if [ "$IOMMU" -eq 0 ]; then
  echo "VEREDICTO: sin grupos IOMMU no hay SR-IOV, ni passthrough, ni vGPU."
  echo "           Activa VT-d/AMD-Vi en la BIOS; si no aparece, tu hardware no lo soporta."
  echo "           Alternativa gratis: comparte el nodo de render -> compartir-gpu.sh"
else
  echo "VEREDICTO: hay $IOMMU grupos IOMMU. Mira arriba si ademas hay mdev o sriov_totalvfs:"
  echo "           si los dos estan vacios, la GPU no soporta reparto aunque el IOMMU si."
fi
