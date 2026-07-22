#!/bin/bash
# ajustes.sh — 4 retoques al manifiesto para un servidor Proxmox REAL (LVM-Thin + LAN 192.168.1.0/24)
set -eu
F=pyme.yaml

# 1) LVM-Thin no entiende qcow2: fuera esa línea (el disco se clona en el formato nativo del pool)
sed -i "/^      format: qcow2$/d" $F

# 2) Clonado ENLAZADO: no copia los 11 GB, referencia la plantilla -> la VM nace en segundos
sed -i "s/^      full: true$/      full: false/" $F

# 3) La red de pods por defecto (192.168.0.0/16) pisa nuestra LAN: la movemos a 10.244.0.0/16
sed -i "s|192.168.0.0/16|10.244.0.0/16|" $F

# 4) El planificador de memoria de CAPMOX suma TODAS las VMs, incluso las apagadas: en un
#    servidor con muchas VMs paradas eso da "0B available memory left". Lo desactivamos.
sed -i "/^kind: ProxmoxCluster$/,/^spec:/ s/^spec:$/spec:\n  schedulerHints:\n    memoryAdjustment: 0/" $F

echo "Manifiesto ajustado. Código completo: github.com/logicalpeyote777/morinicomputers"
