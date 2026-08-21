# home15 — Backup ZFS cifrado al espejo (`zfs send -w`)

Scripts del tutorial «Backup ZFS cifrado: el espejo no lee nada» de Morini Computers (YouTube).
Laboratorio propio y aislado; solo fines educativos.

| Fichero | Qué hace |
|---|---|
| `respaldo-zfs.sh` | Instantánea + envío EN CRUDO (`-w`) al espejo (incremental si hay instantánea común) + retención |
| `copia-zfs.service` | Unidad oneshot que lanza el guion; exige `zfs-import.target` |
| `copia-zfs.timer` | Diario a las 03:30, `Persistent=true` (no se salta el día si la máquina estaba apagada) |
| `vigila-copia.sh` | Avisa si el espejo NO está o si su última instantánea es demasiado vieja |

Montaje en el vídeo:

```sh
# origen cifrado (la clave del vídeo es FALSA: en tu máquina no se teclea en pantalla)
zpool create -o ashift=12 datos /dev/disk/by-id/<id-del-disco>
zfs create -o encryption=aes-256-gcm -o keyformat=passphrase \
           -o keylocation=file:///etc/zfs/claves/datos.key datos/facturas

# espejo de destino
zpool create -o ashift=12 respaldo mirror /dev/disk/by-id/<id-a> /dev/disk/by-id/<id-b>

# la copia (¡con -w! sin ella el destino queda EN CLARO)
zfs snapshot datos/facturas@t0
zfs send -w datos/facturas@t0 | zfs recv respaldo/facturas
```

Al recibir en crudo, `keylocation` queda en `prompt`: vuelve a fijarla con
`zfs set keylocation=file:///etc/zfs/claves/datos.key datos/facturas` tras una restauración.
