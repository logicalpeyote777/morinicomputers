# tut43 — Disaster recovery de un clúster Proxmox

Un nodo del clúster muere en seco (apagón, disco roto, lo que sea). El clúster se queda
sin quórum, las VMs que estaban en ese nodo no las puedes arrancar en ningún sitio, y el
nodo muerto sigue "ocupando su silla" en la configuración. Este vídeo respalda lo mínimo
imprescindible ANTES del desastre, y luego recupera el clúster de verdad: rescate del
quórum, limpieza del nodo caído, alta de un nodo nuevo y reincorporación al clúster.

Vídeo: canal Morini Computers · https://www.youtube.com/@morinicomputers

## Ficheros
- `comandos.md` — todos los comandos del vídeo, en orden, con las salidas/errores reales.
- `respaldo-cluster.sh` — empaqueta la configuración del clúster (pmxcfs + corosync + red)
  y saca la copia fuera del nodo. Se puede dejar en cron: tarda menos de 2 segundos.

## El escenario del lab

Clúster **`morini`** de 2 nodos:
- `pve-a` — `192.168.1.71`
- `pve-b` — `192.168.1.72` — aquí vive la VM 400 `facturacion`

Y un servidor nuevo, recién instalado de cero: `pve-c` — `192.168.1.73`.

## Qué hay que respaldar (y por qué)

Una copia de las VMs (`vzdump`) **no basta** para recuperar el clúster: te devuelve los
discos, pero no la identidad del clúster en sí. Lo que hay que salvar aparte:

- **`/etc/pve`** — es `pmxcfs`, un sistema de ficheros FUSE que vive en RAM y se sincroniza
  entre nodos vía corosync. Aquí están las VMs definidas, usuarios, storages, firewall.
- **`/var/lib/pve-cluster/config.db`** — la base de datos SQLite que hay DEBAJO de pmxcfs.
  Es la que resucita un clúster muerto del todo (si `/etc/pve` no monta, se reconstruye
  desde aquí).
- **`/etc/corosync/corosync.conf`** — la lista de nodos del clúster y su configuración de red.
- **`/etc/network/interfaces`** y **`/etc/hosts`** — sin esto el nodo nuevo no encaja en la
  misma red/nombres que el resto.

Una copia que vive en la propia máquina que se puede morir no es una copia: `respaldo-cluster.sh`
saca siempre una copia fuera del nodo (NAS por NFS).

## Requisito para el nodo que entra

El nodo que se incorpora al clúster (`pve-c` en este vídeo) tiene que ser una
**instalación limpia** (nunca perteneció a otro clúster) y con la **misma versión de
Proxmox** que el resto del clúster. Unir versiones distintas no está soportado.

## Secuencia de recuperación (resumen)

1. Respaldo previo al desastre: `respaldo-cluster.sh` + `vzdump` de las VMs críticas,
   ambos fuera del nodo.
2. Se cae `pve-b` en bruto → el clúster pierde el quórum (`Quorate: No`).
3. Rescate temporal del quórum en el nodo superviviente: `pvecm expected 1`, para poder
   seguir operando (arrancar VMs) mientras se decide qué hacer con el nodo caído.
4. Limpieza: se guarda la config de las VMs del nodo muerto, se le hace `pvecm delnode`
   y se borra su carpeta en `/etc/pve/nodes/`.
5. Se prepara el nodo nuevo (`pve-c`): misma versión de Proxmox, reloj sincronizado, red
   correcta, y se une al clúster con `pvecm add`.
6. Se restaura la VM desde el `vzdump` guardado fuera del nodo y se arranca.

Detalle completo, con las salidas reales del laboratorio, en `comandos.md`.
