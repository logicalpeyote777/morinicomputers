# Comandos del vídeo (en orden)

## 1) Token API con privilegios mínimos (en el host Proxmox)
```bash
pveum role add CSI -privs "VM.Audit VM.Config.Disk Datastore.Allocate Datastore.AllocateSpace Datastore.Audit"
pveum user add kubernetes-csi@pve
pveum aclmod / -user kubernetes-csi@pve -role CSI
pveum user token add kubernetes-csi@pve csi -privsep 0 --output-format json | tee token.json
```

## 2) Etiquetas de topología (region = nombre del clúster en la config; zone = nodo Proxmox)
```bash
kubectl label nodes k8s-cp k8s-w1 topology.kubernetes.io/region=homelab
kubectl label nodes k8s-cp k8s-w1 topology.kubernetes.io/zone=proxmox
kubectl get nodes -L topology.kubernetes.io/region -L topology.kubernetes.io/zone
```

## 3) Instalar el plugin (helm, chart OCI oficial)
```bash
kubectl create ns csi-proxmox
kubectl label ns csi-proxmox pod-security.kubernetes.io/enforce=privileged
helm upgrade -i -n csi-proxmox -f values.yaml proxmox-csi-plugin oci://ghcr.io/sergelogvinov/charts/proxmox-csi-plugin
kubectl -n csi-proxmox rollout status deploy/proxmox-csi-plugin-controller --timeout=180s
kubectl get sc proxmox-lvm
```

## 4) Pedir disco y consumirlo
```bash
kubectl apply -f pvc.yaml        # se queda Pending: WaitForFirstConsumer (diseño, no error)
kubectl apply -f pod.yaml        # al programarse el pod, Proxmox crea y engancha el volumen
kubectl get pvc datos-app        # Bound
kubectl exec app -- df -h /datos
```

## 5) El volumen visto desde Proxmox
```bash
pvesm list vmstore | grep pvc
lvs | grep pvc
qm config 321 | grep pvc         # scsi1 enganchado a la VM del worker
```

## 6) Persistencia real
```bash
kubectl exec app -- sh -c 'echo "pedidos-2026: 41.250 EUR" > /datos/datos.txt'
kubectl delete pod app
kubectl apply -f pod.yaml
kubectl exec app -- cat /datos/datos.txt   # intacto
```

## 7) Ampliar en caliente (2Gi -> 4Gi)
```bash
kubectl patch pvc datos-app -p '{"spec":{"resources":{"requests":{"storage":"4Gi"}}}}'
kubectl exec app -- df -h /datos           # 3.9G sin reiniciar nada
```

## Error clásico (el del Short): PVC en Pending + «failed to get proxmox storage config: not found»
Al usuario del plugin le falta el rol (sin permisos no VE los storage):
```bash
pveum aclmod / -user kubernetes-csi@pve -role CSI
```
