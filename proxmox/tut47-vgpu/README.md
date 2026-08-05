# tut47 — Comparte una GPU en Proxmox sin licencia vGPU

Código del vídeo: cómo saber en **3 comandos** si tu hardware sirve de verdad para
vGPU/SR-IOV, y cómo repartir la GPU que **ya tienes** entre varios contenedores LXC
con VA-API, sin licencias.

## Qué hay aquí

| Fichero | Para qué |
|---|---|
| `comprobar-vgpu.sh` | El veredicto: ¿esta máquina soporta mdev / SR-IOV / IOMMU? |
| `compartir-gpu.sh` | Da el nodo de render a un contenedor LXC y deja el driver correcto |
| `tres.sh` | Lanza el mismo transcode VA-API en 3 contenedores a la vez y mide la GPU |
| `comandos.md` | Todos los comandos del vídeo, uno a uno |

## Resultados medidos en el vídeo

Servidor real: Proxmox VE 9.2, iGPU Intel integrada, fuente 1080p30 de 10 s.

| Prueba | Tiempo real | Tiempo de CPU |
|---|---|---|
| `libx264` (CPU) | **32,5 s** | 32,2 s |
| `h264_vaapi` (GPU) | **4,3 s** | 1,0 s |
| 3 contenedores a la vez (GPU) | **10 s cada uno** | motor de render al 93 % |

Licencias vGPU pagadas: **0**.

## Aviso honesto

Compartir el nodo de render **no es vGPU**. No hay aislamiento duro ni QoS por
invitado: los contenedores se reparten la tarjeta por las buenas. Sirve de sobra para
transcodificación (Jellyfin, Plex, Immich, Frigate) y cargas VA-API en LXC. Si
necesitas escritorios VDI Windows, CUDA dentro de una VM o garantías por máquina,
entonces sí necesitas vGPU/SR-IOV de verdad — y con ello, el hardware y las licencias
que exige.

## Uso rápido

```bash
# 1. ¿mi servidor soporta vGPU/SR-IOV?
./comprobar-vgpu.sh

# 2. dar la GPU al contenedor 9501
./compartir-gpu.sh 9501

# 3. probar los tres a la vez
./tres.sh
```

Canal: **Morini Computers** — Proxmox e infraestructura para pymes.
