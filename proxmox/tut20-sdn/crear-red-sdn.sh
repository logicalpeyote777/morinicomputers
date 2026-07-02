#!/bin/bash
# crear-red-sdn.sh <zona> <vnet> <cidr>
# Crea una red virtual aislada en el SDN de Proxmox (zona simple + VNet +
# subred con gateway y SNAT) y la APLICA a todo el clúster.
# Idempotente con la zona: si ya existe, la reutiliza.
set -euo pipefail
ZONA="${1:?uso: crear-red-sdn.sh <zona> <vnet> <cidr>   (ej: devel dev0 10.80.0.0/24)}"
VNET="${2:?falta el nombre de la VNet (máx. 8 caracteres)}"
CIDR="${3:?falta la subred, ej. 10.80.0.0/24}"
GW="$(echo "$CIDR" | cut -d/ -f1 | awk -F. '{printf "%s.%s.%s.1", $1, $2, $3}')"
echo "==> zona '$ZONA' (simple)"
pvesh get "/cluster/sdn/zones/$ZONA" >/dev/null 2>&1 \
  || pvesh create /cluster/sdn/zones --zone "$ZONA" --type simple
echo "==> VNet '$VNET' + subred $CIDR (gw $GW, SNAT)"
pvesh create /cluster/sdn/vnets --vnet "$VNET" --zone "$ZONA"
pvesh create "/cluster/sdn/vnets/$VNET/subnets" --subnet "$CIDR" --type subnet --gateway "$GW" --snat 1
echo "==> aplico el SDN a todo el clúster"
pvesh set /cluster/sdn
echo "==> red '$VNET' ($CIDR, gw $GW, SNAT) lista en todos los nodos"
