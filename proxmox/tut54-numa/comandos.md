# Comandos del vídeo, en orden

VM del ejemplo: **5400** (`tiempo-real`, Debian 12, 2 vCPU, 2 GB, IP 192.168.1.54).
Hipervisor: Proxmox VE 9.2, Intel de 4 núcleos / 8 hilos, 1 nodo NUMA.

## 0. Preparar la VM de prueba

```bash
qm clone 9000 5400 --name tiempo-real --full --storage vmstore
qm set 5400 --cores 2 --memory 2048 --ipconfig0 ip=192.168.1.54/24,gw=192.168.1.1
qm start 5400
```

Dentro de la VM, la herramienta de medición:

```bash
sudo apt-get install -y rt-tests
```

## 1. El estado de partida

```bash
qm config 5400
```
Ni `affinity`, ni `numa`, ni `hugepages`: la configuración con la que sale una VM
al darle a *Crear* en la interfaz.

## 2. El vecino ruidoso

```bash
./cargar.sh
```
Ocho procesos ocupando los ocho hilos del servidor. **La misma carga** se usa en la
medición de antes y en la de después; si cambia entre las dos, la comparación no
vale nada.

## 3. Medir la latencia REAL dentro de la VM

```bash
./medir.sh antes
```
Que por dentro es:
```bash
ssh luca@192.168.1.54 "sudo cyclictest --mlockall --priority=90 --interval=200 --duration=40 --quiet"
```
- `--priority=90` → hilo con prioridad de tiempo real.
- `--interval=200` → pide despertarse cada 200 µs exactos.
- `--duration=40` → 40 segundos de muestreo.

Salida real de la medición de partida:
```
T: 0 (417) P:90 I:200 C: 187333 Min: 11 Act: 118 Avg: 87 Max: 25032
```
El número que importa es **Max**: 25.032 µs = 25 ms en los que la VM no existió.
Una centralita no se rompe por la media, se rompe por el peor caso.

## 4. Leer la topología del servidor antes de tocar nada

```bash
lscpu -e=CPU,CORE,SOCKET,NODE
numactl --hardware | head -5
```
- Columna `CORE`: el hilo 0 y el 4 son el **mismo** núcleo físico (Hyper-Threading),
  igual que 1-5, 2-6 y 3-7.
- Un solo nodo NUMA → toda la memoria está a la misma distancia. Con dos zócalos
  verías dos nodos, y entonces sí importa dónde cae la memoria de la VM.

## 5. Ver por qué la VM sufre

```bash
PID=$(cat /run/qemu-server/5400.pid)
taskset -cp $PID
ps -To tid,comm -p $PID | grep KVM
```
`lista de afinidad actual: 0-7` → los hilos vCPU pueden acabar en cualquiera de los
ocho hilos, y el planificador los mueve cuando le conviene. Cada mudanza tira la
caché del núcleo anterior.

## 6. Pinning + NUMA

```bash
qm set 5400 --numa 1 --affinity 2,3 --cpuunits 10000
```
Se reservan **núcleos físicos enteros** (2 y 3). Reservar `4-7` sería quedarse con
los hermanos Hyper-Threading de `0-3`: medias unidades de ejecución.

## 7. Hugepages

```bash
grep -iE '^HugePages_(Total|Free)|^Hugepagesize' /proc/meminfo
ls /sys/kernel/mm/hugepages/          # qué tamaños soporta este sistema
sysctl -w vm.nr_hugepages=1100        # 1100 x 2 MiB
qm set 5400 --hugepages 2 --balloon 0 --cpu host
```

Persistente en `/etc/sysctl.d/99-hugepages.conf`:
```
vm.nr_hugepages = 1100
```

⚠️ `--hugepages 1024` (páginas de 1 GB) falla con
`your system doesn't support hugepages of 1024 MB` si la CPU no tiene `pdpe1gb`:
```bash
grep -c pdpe1gb /proc/cpuinfo     # 0 = esta CPU no las tiene
```

## 8. Reiniciar la VM y COMPROBAR (no fiarse)

```bash
qm stop 5400; sleep 8; qm start 5400; sleep 25
taskset -cp $(cat /run/qemu-server/5400.pid)      # -> 2,3
grep -iE '^HugePages_(Total|Free)' /proc/meminfo  # -> Total: 1024  Free: 0
```
`Free: 0` = la VM está usando todas las páginas grandes: su memoria va sobre 2 MiB.

## 9. Aislar los núcleos en caliente

```bash
./aislar.sh
```
Que por dentro es:
```bash
for AMBITO in init.scope system.slice user.slice; do
  systemctl set-property --runtime "$AMBITO" AllowedCPUs=0,1,4,5
done
```
Verificación contra el kernel:
```bash
cat /sys/fs/cgroup/system.slice/cpuset.cpus.effective   # 0-1,4-5
cat /sys/fs/cgroup/qemu.slice/cpuset.cpus.effective     # 0-7 (sin límite)
```
`--runtime` no escribe nada en disco: se revierte con un reinicio.

## 10. Aislamiento permanente (requiere reiniciar)

```bash
sed -i 's|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT="quiet isolcpus=2,3,6,7 nohz_full=2,3,6,7 rcu_nocbs=2,3,6,7"|' /etc/default/grub
grep GRUB_CMDLINE_LINUX_DEFAULT /etc/default/grub
update-grub
```

## 11. Medir otra vez y comparar

```bash
./cargar.sh
./medir.sh despues
./comparar.sh
```
```
                               Min(us)   Avg(us)     Max(us)
  ANTES  por defecto                11        87       25032
  DESPUES pin+HP+aislado             8        29        3741

  peor caso: 25032 us -> 3741 us   =  6.7 veces mejor
  en cristiano: 25.0 ms de parada -> 3.74 ms
```

## 12. Averiguar el suelo de tu hardware

```bash
pkill -f 'carga-[p]yme'
./medir.sh suelo
```
Sin carga: **Max 3.688 µs**, casi igual que con el servidor a tope. Lo que queda ya
no depende de Proxmox: es el hardware y el kernel genérico del huésped.
