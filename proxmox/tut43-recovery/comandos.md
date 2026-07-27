# tut43 — Comandos del vídeo, en orden

> Clúster `morini`: `pve-a` (192.168.1.71) + `pve-b` (192.168.1.72, aquí vive la VM 400
> `facturacion`). Nodo nuevo: `pve-c` (192.168.1.73), instalación limpia, misma versión
> de Proxmox que el resto. Cambia las direcciones por las tuyas.

## 0) Estado sano, antes de nada

```bash
pvecm status
# Quorate:          Yes
# Expected votes:   2
# Total votes:      2
```

## 1) Qué es /etc/pve (y por qué no es un directorio cualquiera)

```bash
df -hT /etc/pve
# Filesystem     Type  Size  Used Avail Use% Mounted on
# /dev/fuse      fuse  128M     0  128M   0% /etc/pve

ls /etc/pve
# corosync.conf  datacenter.cfg  firewall  ha  nodes  priv  qemu-server  storage.cfg  user.cfg  ...

ls -lh /var/lib/pve-cluster/config.db
# -rw------- 1 root root 588K jul 27 09:12 /var/lib/pve-cluster/config.db
```

`/etc/pve` es `pmxcfs`: un filesystem FUSE en memoria, sincronizado entre nodos por
corosync. `config.db` es la misma información pero en disco: de ahí se reconstruye si
pmxcfs no llega a montar.

## 2) Respaldo, ANTES de que pase nada

```bash
bash respaldo-cluster.sh
# >> empaquetando la configuración del clúster...
# >> sacando la copia fuera del nodo...
# >> LISTO: /root/dr/respaldos/pve-b-2026-07-27-0915.tar.gz  (68K)
# >>        copia fuera del nodo en /mnt/pve/nfs-ha/dr
```

Paquete de solo **68K**: es configuración, no datos. La copia fuera del nodo
(`/mnt/pve/nfs-ha/dr`) es la que de verdad te salva — una copia que vive en la máquina
que se puede morir no es una copia.

Copia de la VM (esto sí son los datos, aparte de la config del clúster):

```bash
vzdump 400 --dumpdir /mnt/pve/nfs-ha/dr --mode snapshot --compress zstd
# ...
# INFO: Finished Backup of VM 400 (00:01:47)
```

## 3) El desastre: `pve-b` se apaga en bruto

```bash
pvecm status
# Quorate:          No
# Expected votes:   2
# Total votes:      1
```

Efectos reales, en el nodo superviviente (`pve-a`):

```bash
touch /etc/pve/prueba
# touch: cannot touch '/etc/pve/prueba': Permission denied
```

`/etc/pve` pasa a **solo lectura** sin quórum: no puedes tocar la configuración del
clúster (crear/borrar VMs, tocar usuarios, etc.) aunque el nodo que queda esté sano.

```bash
qm start 300
# cluster not ready - no quorum?
```

Tampoco puedes arrancar una VM que estuviera parada, aunque sus discos estén sanos y
locales en `pve-a`.

## 4) Rescate: forzar el quórum a mano

```bash
pvecm expected 1
pvecm status
# Quorate:          Yes
# Expected votes:   1
# Total votes:      1

qm start 300
# (arranca sin más)
```

`pvecm expected 1` le dice al nodo "cuéntate a ti mismo como si fueras todo el clúster".
**Solo hazlo cuando sepas con certeza que el otro nodo está de verdad muerto** (ver
aviso al final).

## 5) Limpiar el nodo muerto

```bash
# guarda la config de sus VMs por si la necesitas luego (no son los discos, solo el config)
cp -a /etc/pve/nodes/pve-b/qemu-server /root/dr/confs-pve-b

pvecm delnode pve-b
# Killing node 2

rm -rf /etc/pve/nodes/pve-b
```

## 6) El nodo nuevo, antes de unirlo

```bash
pveversion
# pve-manager/9.2.3/...  (misma versión que pve-a)

pvecm status
# Error: Corosync config '/etc/pve/corosync.conf' does not exist - is this node part of a cluster?
```

Ese error es el esperado en un nodo que todavía no pertenece a ningún clúster.

```bash
timedatectl
# System clock synchronized: yes    <- imprescindible, corosync es sensible al reloj

hostname --ip-address
# 192.168.1.73
```

## 7) Unir el nodo nuevo al clúster

```bash
pvecm add 192.168.1.71 --use_ssh 1
# ...
# successfully added node 'pve-c' to cluster.

pvecm status
# Quorate:          Yes
# Expected votes:   2
# Total votes:      2
```

## 8) Restaurar la VM en el nodo que hace falta

```bash
qmrestore /mnt/pve/nfs-ha/dr/vzdump-qemu-400-*.vma.zst 400 --storage local
qm start 400
```

### ⚠️ Aviso real, encontrado grabando

Al restaurar, **cloud-init regenera las claves de host SSH** de la VM (son nuevas, no
las de antes del desastre). El primer `ssh` a la VM restaurada da:

```
WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!
```

Se arregla borrando la huella vieja del `known_hosts` local:

```bash
ssh-keygen -R 192.168.1.73
```

(o la IP que tenga la VM restaurada — no es un fallo de la restauración, es cloud-init
haciendo su trabajo).

## Qué NO hacer

- **No hagas `pvecm expected 1` "por si acaso".** Solo cuando tengas la certeza de que el
  otro nodo está de verdad muerto (apagado, destruido). Si solo está incomunicado pero
  sigue vivo y con sus propias VMs corriendo, forzar el quórum en los dos lados a la vez
  es la receta exacta del **split-brain**: dos nodos "convencidos" de mandar sobre el
  mismo clúster, cada uno con su propia idea de la configuración.
- **Un nodo borrado con `pvecm delnode` no puede volver con la misma identidad.** Si
  luego resucitas el hardware/VM de `pve-b`, NO lo reincorpores tal cual al clúster: ya
  fue purgado de `/etc/pve/nodes` y de corosync. Trátalo como una instalación limpia
  nueva (reinstala, o al menos reinicializa pmxcfs) antes de unirlo, igual que hicimos
  con `pve-c`.
