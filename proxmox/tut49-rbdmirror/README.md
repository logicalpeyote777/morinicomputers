# tut49 — Ceph replicado entre dos sedes (RBD mirroring)

Replicación **asíncrona** de Ceph entre **dos clústeres Proxmox distintos**, con
`rbd-mirror`: modo journal vs snapshot, emparejamiento (peer bootstrap),
`demote` / `promote` y failover de recuperación ante desastres.

No confundir:

| Herramienta | Qué es | Alcance |
|---|---|---|
| Replicación ZFS de Proxmox | copia periódica de un disco ZFS | **mismo clúster** |
| Proxmox Backup Server | copia de seguridad + restauración | cualquier sitio, pero **restaurar tarda** |
| **RBD mirroring** | el disco **vivo** en los dos sitios | **dos clústeres Ceph distintos** |

## Laboratorio

Dos clústeres Proxmox VE 9 de **un nodo**, cada uno con su propio Ceph Squid
(mon + mgr + 1 OSD) y el pool `cephdr` — el nombre del pool tiene que ser **el
mismo en los dos**.

```
pve-mad  10.50.0.21   "sede de Madrid"     primario   -> VM 100 web-madrid (disco en cephdr)
pve-val  10.50.0.22   "sede de Valencia"   DR
```

## Ficheros

| Fichero | Para qué |
|---|---|
| `comandos.md` | todos los comandos del vídeo, en orden |
| `medir-rpo.sh` | mide el **RPO real** (segundos) de un espejo en modo snapshot |
| `comprobar-mirror.sh` | salud del espejo: demonio, pareja, imágenes y edad del último snapshot |
| `cuando.txt` | cuándo compensa RBD mirroring y cuándo no |

## Lo que más se falla

1. **El demonio no tiene llavero.** `rbd-mirror` necesita su propio usuario
   (`client.rbd-mirror.<sede>`). Sin él, el pool dice `enabled`, la pareja
   aparece bien... y las imágenes se quedan en `unknown` para siempre.
2. **Modo journal sin medir el coste.** Duplica las escrituras en tu disco.
3. **El pool se llama distinto** en cada sede.
4. **`promote --force` sin `demote`** = split-brain. Se arregla con
   `rbd mirror image resync` en el lado que se rinde.
5. **Esto no sustituye a las copias**: un borrado se replica igual de rápido.
