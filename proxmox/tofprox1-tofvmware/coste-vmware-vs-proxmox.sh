#!/bin/bash
# coste-vmware-vs-proxmox.sh — calculadora de coste anual: VMware (Broadcom) vs Proxmox VE.
#
# Morini Computers (YouTube) — vídeo "Por qué las empresas abandonan VMware en 2026".
# Tras la compra por Broadcom (2024), VMware pasó a SUSCRIPCIÓN por NÚCLEO, con un mínimo
# de 16 núcleos facturables por CPU y en paquetes (VVF / VCF). Esta calculadora estima el
# gasto anual y lo compara con Proxmox VE (licencia 0; soporte opcional).
#
# Los PRECIOS de abajo son de LISTA, citados públicamente: AJÚSTALOS a tu presupuesto real
# (tu partner/integrador te dará el tuyo). Lo que no cambia es el método de cálculo.
#
# Uso:  coste-vmware-vs-proxmox.sh [sockets] [nucleos_por_socket]
#   ej: coste-vmware-vs-proxmox.sh 2 32
set -u

SOCKETS="${1:-2}"        # nº de CPUs físicas del servidor
NUCLEOS="${2:-32}"       # núcleos por CPU
MIN_NUCLEOS=16           # mínimo facturable por CPU (regla Broadcom)

# --- precios de lista (edítalos a tu caso) ---
PRECIO_VVF=135           # $/núcleo/año  · VMware vSphere Foundation
PRECIO_VCF=350           # $/núcleo/año  · VMware Cloud Foundation
SOPORTE_PVE=115          # €/CPU/año     · Proxmox VE, suscripción Community (OPCIONAL)

# núcleos facturables = sockets * max(nucleos, minimo)
por_cpu=$(( NUCLEOS > MIN_NUCLEOS ? NUCLEOS : MIN_NUCLEOS ))
fact=$(( SOCKETS * por_cpu ))

vvf=$(( fact * PRECIO_VVF ))
vcf=$(( fact * PRECIO_VCF ))
pve_sop=$(( SOCKETS * SOPORTE_PVE ))

echo "============================================================"
echo " Servidor: ${SOCKETS} CPU x ${NUCLEOS} núcleos = $((SOCKETS*NUCLEOS)) núcleos físicos"
echo " Núcleos FACTURABLES en VMware (mín. ${MIN_NUCLEOS}/CPU): ${fact}"
echo "============================================================"
printf ' VMware vSphere Foundation : %10d $/año\n' "$vvf"
printf ' VMware Cloud Foundation   : %10d $/año\n' "$vcf"
echo   ' Proxmox VE (licencia)     :          0  /año'
printf ' Proxmox VE (soporte opc.) : %10d €/año\n' "$pve_sop"
echo "------------------------------------------------------------"
printf ' AHORRO/año vs VVF         : %10d  (pagando solo soporte Proxmox)\n' "$(( vvf - pve_sop ))"
printf ' AHORRO/año vs VCF         : %10d\n' "$(( vcf - pve_sop ))"
veces=$(( vcf / (pve_sop > 0 ? pve_sop : 1) ))
echo "------------------------------------------------------------"
echo " >> Con soporte oficial, Proxmox cuesta ~${veces}x menos que VMware Cloud Foundation."
echo " >> Sin soporte (community), la licencia es 0: el ahorro es íntegro, año tras año."
echo "============================================================"
