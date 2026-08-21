# tut54 — Latencia en Proxmox: de 25 ms a 3,7 ms en tu VM

Cómo se mide y cómo se baja la latencia de una máquina virtual de Proxmox que
tiene que responder a tiempo (centralita VoIP, TPV, control industrial): NUMA,
afinidad de CPU (pinning), hugepages y aislamiento de núcleos.

Todos los números de abajo están medidos en cámara sobre un Proxmox VE 9.2 real
(Intel de 4 núcleos / 8 hilos, 1 nodo NUMA), con una VM Debian 12 de 2 vCPU y 2 GB.

## El resultado

| | Min (µs) | Avg (µs) | **Max (µs)** |
|---|---|---|---|
| **ANTES** — VM por defecto | 11 | 87 | **25.032** |
| **DESPUÉS** — pinning + hugepages + aislamiento | 8 | 29 | **3.741** |

Peor caso: 25.032 µs → 3.741 µs = **6,7 veces mejor**. En cristiano: de 25,0 ms de
parada a 3,74 ms. Mismo hardware, misma carga, misma prueba.

> Un paquete de voz sobre IP sale cada 20 ms. Una parada de 25 ms se come un
> paquete entero: eso es el corte que oye el cliente al teléfono.

## Los guiones

| Guion | Qué hace |
|---|---|
| `cargar.sh` | Genera el "vecino ruidoso": 8 procesos ocupando los 8 hilos del hipervisor. La **misma** carga en las dos mediciones — si la cambias, no estás comparando nada. |
| `medir.sh <etiqueta>` | Lanza `cyclictest` dentro de la VM (prioridad 90, cada 200 µs, 40 s) y guarda el resultado. El número que importa es **Max**, no la media. |
| `aislar.sh` | Aísla núcleos **en caliente**, sin reiniciar: cgroups v2 + `systemctl set-property --runtime`. |
| `comparar.sh` | Pone las dos mediciones lado a lado y calcula el factor de mejora. |
| `cuando.txt` | Cuándo SÍ y cuándo NO merece la pena, y las 5 reglas que no se saltan. |

## Los cuatro cambios, en orden

### 1. Pinning y NUMA

```bash
qm set 5400 --numa 1 --affinity 2,3 --cpuunits 10000
```

- `--numa 1` presenta la topología NUMA al huésped. En un servidor de **dos
  zócalos** es lo que permite que vCPU y memoria acaben en el mismo nodo; cruzar
  el bus entre zócalos se paga en cada acceso a memoria.
- `--affinity 2,3` clava los hilos vCPU a esos núcleos.
- `--cpuunits 10000` sube el peso de esta VM frente a las demás al repartir CPU.

**Mira la topología ANTES de elegir los números:**

```bash
lscpu -e=CPU,CORE,SOCKET,NODE
```

```
CPU CORE SOCKET NODE
  0    0      0    0
  1    1      0    0
  2    2      0    0
  3    3      0    0
  4    0      0    0     <-- el hilo 4 es el MISMO núcleo que el 0
  5    1      0    0
  6    2      0    0
  7    3      0    0
```

En esta CPU, reservar `4-7` sería reservar los **hermanos Hyper-Threading** de
`0-3`: medias unidades de ejecución. Se reservan **núcleos físicos enteros**.

### 2. Hugepages, ballooning y modelo de CPU

```bash
sysctl -w vm.nr_hugepages=1100          # 1100 x 2 MiB, algo más de lo que pide la VM
qm set 5400 --hugepages 2 --balloon 0 --cpu host
```

- **Hugepages**: de páginas de 4 KiB a 2 MiB. Los mismos 2 GB pasan de más de
  medio millón de páginas a 1.024 → la TLB deja de fallar constantemente.
- **`--balloon 0`**: una VM de tiempo real no puede tener la memoria bailando debajo.
- **`--cpu host`**: el huésped usa el reloj y las instrucciones nativas en vez de
  salir al hipervisor a preguntar la hora.

**La comprobación que no se salta** (después de reiniciar la VM):

```bash
taskset -cp $(cat /run/qemu-server/5400.pid)     # -> 2,3   (ya no 0-7)
grep -iE '^HugePages_(Total|Free)' /proc/meminfo # -> Total: 1024, Free: 0
```

`HugePages_Free: 0` significa que la VM las está usando **todas**: su memoria está
respaldada por páginas grandes de verdad.

⚠️ **Páginas de 1 GB**: `--hugepages 1024` falla con
`your system doesn't support hugepages of 1024 MB` si la CPU no tiene el
indicador `pdpe1gb` (`grep -c pdpe1gb /proc/cpuinfo`) o si no las reservaste en el
arranque del kernel. Comprueba qué tamaños hay: `ls /sys/kernel/mm/hugepages/`.

### 3. Aislar los núcleos EN CALIENTE (sin reiniciar)

`aislar.sh` manda todo lo que **no** es una máquina virtual a los hilos `0,1,4,5`
y deja `2,3,6,7` (núcleos físicos 2 y 3 enteros) libres:

```bash
for AMBITO in init.scope system.slice user.slice; do
  systemctl set-property --runtime "$AMBITO" AllowedCPUs=0,1,4,5
done
```

Con `--runtime` **no se escribe nada en disco**: si algo sale mal, reinicias y
todo vuelve a estar como estaba. Por eso se puede probar en producción.

Verifica contra el kernel, no contra lo que tú creas:

```bash
cat /sys/fs/cgroup/system.slice/cpuset.cpus.effective   # 0-1,4-5
cat /sys/fs/cgroup/qemu.slice/cpuset.cpus.effective     # 0-7 (sin límite)
```

### 4. Aislamiento duro y permanente (isolcpus)

En `/etc/default/grub`:

```
GRUB_CMDLINE_LINUX_DEFAULT="quiet isolcpus=2,3,6,7 nohz_full=2,3,6,7 rcu_nocbs=2,3,6,7"
```

```bash
update-grub    # entra en el siguiente reinicio
```

- `isolcpus` saca esos hilos del planificador general del kernel.
- `nohz_full` quita el tic del reloj cuando solo hay una tarea corriendo.
- `rcu_nocbs` se lleva el trabajo de reciclado del kernel a otros núcleos.

Este es el aislamiento que también aparta a los **hilos del propio kernel**; el
del punto 3 es el que puedes aplicar sin reiniciar el servidor.

## Cómo reproducirlo

```bash
./cargar.sh            # el vecino ruidoso
./medir.sh antes       # 40 s de cyclictest dentro de la VM
# ... aplicar los 4 cambios y reiniciar la VM ...
./aislar.sh
./cargar.sh
./medir.sh despues
./comparar.sh
```

## El suelo de tu hardware

Con el servidor **vacío** y la VM ya configurada, el máximo se queda en **3.688 µs**:
casi lo mismo que con el servidor a tope. Lo que queda ya no es el vecino ruidoso,
es el suelo de ese hardware y de un kernel genérico. Para bajar de ahí lo siguiente
no es tocar Proxmox: es un kernel con `PREEMPT_RT` en el huésped y hardware de
servidor. Saber dónde está tu suelo evita perder una tarde apretando tornillos que
ya están apretados.

## Las 5 reglas que no se saltan

1. Deja siempre núcleos al hipervisor.
2. Una VM de tiempo real por juego de núcleos; nunca dos en los mismos.
3. Reserva núcleos **físicos** enteros, no hilos sueltos.
4. Con dos zócalos, la VM entera dentro de un nodo NUMA.
5. Mide antes y mide después: sin número no hay mejora, hay fe.
