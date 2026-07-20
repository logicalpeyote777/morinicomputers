# tut40 — Almacenamiento nativo de Proxmox para tu Kubernetes (Proxmox CSI Plugin)

PersistentVolumes dinámicos sobre LVM-Thin: tus pods piden disco con un PVC y
Proxmox crea el volumen al vuelo en `vmstore`, lo engancha a la VM del nodo y lo
monta en el contenedor. Sin NFS, sin nube.

Vídeo: canal Morini Computers · https://www.youtube.com/@morinicomputers

## Ficheros
- `comandos.md` — todos los comandos del vídeo, en orden.
- `values.example.yaml` — configuración del chart (pon tu token real).
- `pvc.yaml` / `pod.yaml` — la reclamación de 2Gi y el pod que la consume.

Plugin: https://github.com/sergelogvinov/proxmox-csi-plugin
