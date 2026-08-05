# Comandos del vídeo, uno a uno

Todo se lanza desde la shell del **host** Proxmox (`root@pve`).

## 1. ¿esta GPU sirve para vGPU?

```bash
lspci -nnk | grep -A3 -i vga
```

Fíjate en `Kernel driver in use`. El driver genérico (`i915`, `amdgpu`, `nouveau`)
**no** es el driver de vGPU del fabricante.

## 2. Mediated devices (mdev) — la vía de NVIDIA vGPU

```bash
ls /sys/bus/pci/devices/*/mdev_supported_types
mdevctl types
ls /sys/bus/mdev/devices | wc -l
```

Si no existe el fichero y `mdevctl types` no devuelve nada, no hay vGPU de NVIDIA
posible en esa máquina.

## 3. SR-IOV y los grupos IOMMU

```bash
ls /sys/bus/pci/devices/*/sriov_totalvfs
ls /sys/kernel/iommu_groups | wc -l
dmesg | grep -ci DMAR
```

**0 grupos IOMMU = se acabó**: sin VT-d/AMD-Vi no hay SR-IOV, ni passthrough, ni vGPU.
Actívalo en la BIOS; si no aparece la opción, el hardware no lo soporta.

## 4. Lo que vGPU de verdad exige

1. GPU de gama datacenter (NVIDIA vGPU/Tesla, Intel Flex o 12ª gen+, AMD MxGPU) — no tarjetas de consumo.
2. IOMMU / VT-d (o AMD-Vi) activado en la BIOS.
3. Driver vGPU del fabricante en el host (no el `i915` genérico).
4. NVIDIA además exige servidor de licencias y suscripción activa **por VM**.
5. Intel SR-IOV (Flex / 12ª gen+) es gratis, pero solo en hardware compatible.

## 5. El nodo de render (la alternativa gratuita)

```bash
ls -l /dev/dri/
getent group render
```

- `card1` → la **pantalla**. Uno solo puede tenerla.
- `renderD128` → el **motor** de cálculo y vídeo, sin pantalla. Lo pueden abrir varios a la vez.

Apunta el `gid` del grupo `render` (en el vídeo: `992`).

## 6. Dar la GPU a un contenedor (una línea)

```bash
pct set 9501 --dev0 /dev/dri/renderD128,gid=992
pct config 9501 | grep -E "dev0|unprivileged"
```

`unprivileged: 1` — no hace falta bajar ninguna defensa para compartir la GPU.

## 7. El driver correcto dentro del contenedor

```bash
pct exec 9501 -- ls /usr/lib/x86_64-linux-gnu/dri/ | grep drv_video
pct exec 9501 -- dpkg -l | grep va-driver
```

- Intel **Gen 6-9** (Sandy Bridge … Coffee Lake) → `i965-va-driver`
- Intel **Gen 11+** (Ice Lake en adelante) → `intel-media-va-driver` (iHD)

Poner el que no toca da `vaInitialize failed with error code 1` y parece que la GPU
no está. No lo está: está el driver equivocado.

## 8. La prueba: el contenedor ve la GPU

```bash
pct exec 9501 -- vainfo --display drm --device /dev/dri/renderD128 | head -14
pct exec 9501 -- ls -l /dev/dri/
```

Busca `VAEntrypointEncSlice`: eso es **codificar por hardware**, lo que te ahorra la CPU.
Dentro del contenedor solo está `renderD128`, no `card1`.

## 9. El antes y el después (medido)

```bash
# CPU — 32,5 s reales, 32,2 s de CPU quemada
pct exec 9501 -- bash -c 'time ffmpeg -y -i /root/origen.mp4 \
  -c:v libx264 -preset medium -b:v 3M -an /root/cpu.mp4'

# GPU — 4,3 s reales, 1,0 s de CPU
pct exec 9501 -- bash -c 'export LIBVA_DRIVER_NAME=i965; time ffmpeg -y \
  -hwaccel vaapi -vaapi_device /dev/dri/renderD128 -i /root/origen.mp4 \
  -vf format=nv12,hwupload -c:v h264_vaapi -b:v 3M -an /root/gpu.mp4'
```

El fichero de prueba se genera así:

```bash
ffmpeg -y -f lavfi -i testsrc2=size=1920x1080:rate=30 -f lavfi -i sine=frequency=440 \
  -t 10 -c:v libx264 -preset veryfast -crf 20 -c:a aac -shortest /root/origen.mp4
```

## 10. Los tres a la vez

```bash
cat tres.sh     # léelo antes de lanzarlo
./tres.sh
```

Los tres contenedores terminan en 10 s, motor de render al ~93 %.

## 11. ¿Nodo de render compartido o vGPU de verdad?

**Basta el nodo compartido:** transcodificación (Jellyfin, Plex, Immich, Frigate),
miniaturas, cargas VA-API en LXC, varios invitados codificando a la vez.

**Necesitas vGPU/SR-IOV:** escritorios VDI Windows, CUDA/IA dentro de una VM,
aislamiento duro y QoS por máquina, OpenGL/DirectX completo.
