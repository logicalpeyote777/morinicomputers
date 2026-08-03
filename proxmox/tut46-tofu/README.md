# tut46 — Crossplane + Proxmox: borro una VM y vuelve sola

Define las VMs de Proxmox como recursos declarativos de Kubernetes (XRD + Composition +
Claim) y deja que el reconciliador las cree, las escale, las **repare** y las destruya.

Vídeo: **Crossplane + Proxmox: borro una VM y vuelve sola** — canal Morini Computers.

## Lo que hay montado

| Pieza | Versión |
|---|---|
| Kubernetes (kubeadm) | v1.30.14, 2 nodos |
| Crossplane | 1.20.11 (`crossplane-stable/crossplane`, ns `crossplane-system`) |
| Provider | `xpkg.upbound.io/upbound/provider-terraform:v0.20.0` |
| Function | `crossplane-contrib/function-patch-and-transform:v0.9.0` — **obligatoria desde Crossplane 1.17** |
| Provider Terraform | `bpg/proxmox` 0.87.0 (se descarga solo en el `terraform init` del pod) |
| Proxmox VE | 9.2 |

## Orden de aplicación

```sh
helm repo add crossplane-stable https://charts.crossplane.io/stable && helm repo update
helm install crossplane crossplane-stable/crossplane -n crossplane-system --create-namespace

# 1. token de API en Proxmox (en el HOST Proxmox)
pveum user add crossplane@pve
pveum user token add crossplane@pve xp --privsep 0
pveum acl modify / --user crossplane@pve --role Administrator

# 2. pon el secreto del token en 00-provider.yaml y aplica en orden
kubectl apply -f 00-provider.yaml        # Secret + DeploymentRuntimeConfig + Provider
kubectl apply -f 01-providerconfig.yaml  # provider bpg/proxmox + backend kubernetes
kubectl apply -f 02-function.yaml        # function-patch-and-transform
kubectl apply -f 03-xrd.yaml             # tu tipo propio: kind VM
kubectl apply -f 04-composition.yaml     # la fontanería (módulo HCL embebido)

# 3. y ya puedes pedir máquinas con 11 líneas
kubectl apply -f 05-claim.yaml
```

## Las cuatro operaciones del ciclo de vida

```sh
# CREAR — del apply a la VM encendida en Proxmox
time (kubectl apply -f 05-claim.yaml; until qm list | grep -q web-pyme-1; do sleep 2; done)

# ESCALAR — un número, y salen las que falten
kubectl patch vm web-pyme --type merge -p '{"spec":{"replicas":3}}'

# REPARAR — bórrala a mano en Proxmox y NO hagas nada más
qm stop 4602 && qm destroy 4602

# DESTRUIR — se lleva por delante todas las VMs del claim
kubectl delete vm web-pyme
```

Medido en cámara sobre este mismo laboratorio:

| Operación | Tiempo |
|---|---|
| crear (apply → VM encendida) | **15,5 s** |
| escalar (replicas 1 → 3) | **11,6 s** |
| **auto-reparación** (`qm destroy` → vuelve sola) | **27,8 s** |
| destruir (delete → 0 VMs, 0 workspaces) | **17,9 s** |

## Trampas que cuestan una tarde

- **`--poll-jitter` NUNCA mayor que `--poll`.** El jitter varía el intervalo en ±ese valor;
  con `--poll=15s` y el jitter por defecto (`1m`) el intervalo sale **negativo**, y con un
  intervalo negativo el reconciliador **no vuelve a mirar jamás**. El `Workspace` se queda
  en `SYNCED=True READY=True` y las VMs borradas no vuelven nunca. Aquí va `--poll=30s
  --poll-jitter=5s`.
- **Sin `function-patch-and-transform` no se crea nada.** Desde Crossplane 1.17 el
  `mode: Resources` de las Composition ya no existe; hay que usar `mode: Pipeline`.
- **`defaultCompositionRef` en el XRD**: sin él, el claim no resuelve composición y se
  queda parado sin decir por qué.
- **Bloques HCL de una línea admiten UN solo argumento.** `clone { vm_id = 9000, full = false }`
  falla con *Invalid single-argument block definition* (y en HCL no existe la coma). Un
  argumento por línea.
- **Los errores de Terraform llegan comprimidos.** Para leerlos:
  `echo "H4sIA..." | base64 -d | gunzip`.
- **`agent { enabled = false }`** si la plantilla no lleva `qemu-guest-agent`: si no,
  Terraform se queda esperando la IP hasta el timeout.

## Ficheros

| Fichero | Qué es |
|---|---|
| `00-provider.yaml` | Secret con el token, DeploymentRuntimeConfig (aquí van `--poll` y `--poll-jitter`) y el Provider |
| `01-providerconfig.yaml` | provider `bpg/proxmox` + backend `kubernetes` para el estado de Terraform |
| `02-function.yaml` | function-patch-and-transform |
| `03-xrd.yaml` | el tipo `VM` de tu empresa: `nombre`, `replicas`, `cores`, `memoryMB`, `diskGB` |
| `04-composition.yaml` | el módulo HCL embebido (`count = var.replicas`) y los 6 patches |
| `05-claim.yaml` | lo único que escribe quien pide la máquina: 11 líneas |

---
Todo está probado sobre laboratorio propio. Cambia el endpoint, el token, el `node_name`
y la plantilla que se clona (`vm_id = 9000`) por los tuyos.
