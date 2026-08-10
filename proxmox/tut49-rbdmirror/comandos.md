# Comandos del vídeo, en orden

Todo se lanza desde la sede **de destino** (`pve-val`, Valencia). Los comandos de
la sede primaria van con `ssh pve-mad`.

## 0. Punto de partida

```bash
ceph fsid                       # el fsid de Valencia
rbd ls -l cephdr                # vacío
ssh pve-mad 'ceph fsid'         # otro fsid distinto
ssh pve-mad 'rbd ls -l cephdr'  # aquí vive vm-100-disk-0
```

## 1. Encender el espejo en el pool (en LOS DOS, mismo nombre de pool)

```bash
rbd mirror pool enable cephdr image
ssh pve-mad 'rbd mirror pool enable cephdr image'
rbd mirror pool info cephdr
```

`image` = eliges disco a disco qué se replica. `pool` = todo el pool, automático.

## 2. El demonio (corre en el DESTINO; se instala en los dos para el failback)

```bash
apt-get install -y rbd-mirror
ssh pve-mad 'apt-get install -y rbd-mirror'
```

## 3. Emparejar los dos clústeres (token de bootstrap)

```bash
ssh pve-mad 'rbd mirror pool peer bootstrap create --site-name mad cephdr' > token-mad
rbd mirror pool peer bootstrap import --site-name val --direction rx-tx cephdr token-mad
rbd mirror pool info cephdr --all
```

El token lleva dentro el fsid, los monitores y una clave. **Es una contraseña.**

## 4. El llavero del demonio (EL paso que falta en casi todos los tutoriales)

```bash
ceph auth get-or-create client.rbd-mirror.val \
     mon 'profile rbd-mirror' osd 'profile rbd' \
     -o /etc/ceph/ceph.client.rbd-mirror.val.keyring
systemctl enable --now ceph-rbd-mirror@rbd-mirror.val
rbd mirror pool status cephdr        # daemon health: OK
```

## 5. Modo journal: RPO de segundos, pero DUPLICA las escrituras

```bash
ssh pve-mad 'rbd create cephdr/datos-erp --size 2G'
ssh pve-mad 'rbd feature enable cephdr/datos-erp journaling'
ssh pve-mad 'rbd mirror image enable cephdr/datos-erp journal'
ssh pve-mad 'rbd info cephdr/datos-erp'

# medir el coste:
ssh pve-mad 'ceph df | grep cephdr'
ssh pve-mad 'rbd bench --io-type write --io-size 4M --io-total 512M cephdr/datos-erp'
ssh pve-mad 'ceph df | grep cephdr'      # ~2x lo escrito
```

## 6. Modo snapshot (el que quieres casi siempre)

```bash
ssh pve-mad 'rbd mirror image disable cephdr/datos-erp'
ssh pve-mad 'rbd feature disable cephdr/datos-erp journaling'
ssh pve-mad 'rbd mirror image enable cephdr/datos-erp snapshot'
ssh pve-mad 'rbd mirror image enable cephdr/vm-100-disk-0 snapshot'
rbd mirror image status cephdr/vm-100-disk-0
```

## 7. Programar el ritmo (= tu RPO)

```bash
ssh pve-mad 'rbd mirror snapshot schedule add --pool cephdr --image vm-100-disk-0 1m'
ssh pve-mad 'rbd mirror snapshot schedule ls -p cephdr --recursive'
ssh pve-mad 'rbd mirror snapshot schedule status -p cephdr'
```

## 8. Medir el RPO real

```bash
./medir-rpo.sh
```

## 9. Failover PLANIFICADO

```bash
ssh pve-mad 'qm shutdown 100'
ssh pve-mad 'rbd mirror image demote cephdr/vm-100-disk-0'
rbd mirror image promote cephdr/vm-100-disk-0
qm create 100 --name web-valencia --memory 512 --cores 1 --ostype l26 \
   --scsihw virtio-scsi-single --net0 virtio,bridge=vmbr0 \
   --scsi0 cephdr:vm-100-disk-0 --boot order=scsi0
qm start 100
```

Los **discos** se replican. El **fichero de configuración** de la VM, no:
guárdatelo tú (`/etc/pve/qemu-server/100.conf`).

## 10. Failover de DESASTRE (la sede no contesta)

```bash
rbd mirror image status cephdr/datos-erp          # unknown
rbd mirror image promote --force cephdr/datos-erp
```

Cuando la sede caída vuelva, en **ella** (el lado que se rinde):

```bash
rbd mirror image demote cephdr/datos-erp
rbd mirror image resync cephdr/datos-erp
```

## 11. Salud del espejo

```bash
./comprobar-mirror.sh cephdr
```
