#!/bin/bash
# Copia ZFS del homelab: instantánea -> envío EN CRUDO al espejo -> retención.
# El origen NUNCA se descifra: el espejo guarda los bloques tal cual, cifrados.
set -euo pipefail

ORIGEN="datos/facturas"
ESPEJO="respaldo/facturas"
DIARIAS=7                       # cuántas instantáneas se conservan a cada lado
SELLO="auto-$(date +%Y%m%d-%H%M%S)"

# 1 · Instantánea nueva. Es atómica: todo el conjunto en el MISMO instante.
zfs snapshot "$ORIGEN@$SELLO"

# 2 · ¿Tenemos una instantánea COMÚN con el espejo? Sí -> incremental. No -> completa.
COMUN=""
for S in $(zfs list -H -o name -t snapshot -s creation -d 1 "$ESPEJO" 2>/dev/null | cut -d@ -f2); do
    zfs list -H "$ORIGEN@$S" >/dev/null 2>&1 && COMUN="$S"
done

if [ -n "$COMUN" ]; then
    echo "incremental  @$COMUN -> @$SELLO"
    zfs send -w -i "@$COMUN" "$ORIGEN@$SELLO" | zfs recv "$ESPEJO"
else
    echo "completa     @$SELLO  (no hay instantánea común)"
    zfs send -w "$ORIGEN@$SELLO" | zfs recv -F "$ESPEJO"
fi

# 3 · Retención. Se poda cada lado por separado: el espejo puede guardar más historia
#     que el origen, que es justo lo que quieres de una copia.
for FS in "$ORIGEN" "$ESPEJO"; do
    zfs list -H -o name -t snapshot -s creation -d 1 "$FS" | grep '@auto-' \
        | head -n -"$DIARIAS" | xargs -r -n1 zfs destroy
done

echo "OK  $(zfs list -H -o name -t snapshot -d 1 "$ESPEJO" | wc -l) instantáneas en el espejo"
