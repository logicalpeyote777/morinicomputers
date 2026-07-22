# tut41 — Clústeres Kubernetes bajo demanda en Proxmox (Cluster API / CAPMOX)

Escribes un YAML, lo aplicas, y Proxmox fabrica el clúster ENTERO solo: clona las
máquinas virtuales de una plantilla, las arranca, lanza `kubeadm` y une los nodos.
Escalar es una línea (`kubectl scale machinedeployment`), destruirlo un comando
(`kubectl delete cluster`). Sin nube y sin licencias.

Vídeo: canal Morini Computers · https://www.youtube.com/@morinicomputers

## Ficheros
- `comandos.md` — todos los comandos del vídeo, en orden.
- `plantilla-k8s.sh` — construye la plantilla que clonan los nodos (Debian 12 cloud +
  containerd + kubeadm 1.30 + qemu-guest-agent, limpia y sin unidad cloud-init de Proxmox).
- `cluster.env.example` — parámetros del clúster (nodo, plantilla, IPs, tamaño de las VMs).
- `ajustes.sh` — los 4 retoques al manifiesto generado para que funcione en un servidor real.

## Versiones probadas
Proxmox VE 9.2 · Cluster API v1.10.10 · CAPMOX (ionos-cloud) v0.7.7 ·
IPAM in-cluster v1.0.3 · Kubernetes v1.30.14

> ⚠️ CAPMOX v0.8+/v0.9 exige Cluster API v1.11+, que a su vez pide un clúster de
> gestión con Kubernetes ≥ 1.31. Con un clúster de gestión 1.30, usa las versiones
> clavadas de arriba.

## Los 4 ajustes (y por qué)
1. **Fuera `format: qcow2`** — LVM-Thin no admite qcow2; el disco se clona en el formato del pool.
2. **`full: false`** — clonado enlazado: la VM nace en segundos en vez de copiar 11 GB.
3. **Red de pods `10.244.0.0/16`** — la de fábrica (`192.168.0.0/16`) pisa la LAN doméstica típica.
4. **`schedulerHints.memoryAdjustment: 0`** — el planificador suma la memoria de TODAS las VMs
   (también las apagadas) y responde `0B available memory left` aunque te sobre RAM.

## Errores frecuentes
| Síntoma | Causa | Arreglo |
|---|---|---|
| `not authorized to access endpoint` | al token le faltan roles | `PVEVMAdmin,PVEAuditor,PVEDatastoreAdmin,PVESDNUser` + `-privsep 0` |
| `cannot find node with name <nodo>` | falta `Sys.Audit` (PVEAuditor) | añade el rol |
| `unable to inject CloudInit ISO: unexpected end of JSON input` | no puede subir la ISO | `PVEDatastoreAdmin` sobre el almacenamiento con contenido `iso` |
| `hostname lookup '<nodo>' failed` | el nodo no resuelve su propio nombre | añade la línea del host en `/etc/hosts` |
| `0B available memory left` | planificador de memoria | `schedulerHints.memoryAdjustment: 0` |
| Máquina atascada en `WaitingForCloudInit` | la plantilla conserva la unidad cloud-init de Proxmox | `qm set <vmid> --delete ide2` y volver a crear la plantilla |

Proveedor: https://github.com/ionos-cloud/cluster-api-provider-proxmox
