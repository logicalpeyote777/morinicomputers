# tut41 — Comandos, en orden

Todo se ejecuta desde la consola del host Proxmox, con `kubectl` apuntando al
**clúster de gestión** (`/root/.kube/config`).

## 0. Punto de partida
```bash
kubectl get nodes                          # el clúster de gestión (kubeadm)
qm list | grep -E "k8s-|plantilla-k8s"     # sus VMs + la plantilla
```

## 1. Identidad y token para el controlador
```bash
pveum user add capmox@pve
pveum aclmod / -user capmox@pve -role PVEVMAdmin,PVEAuditor,PVEDatastoreAdmin,PVESDNUser
pveum user token add capmox@pve capi -privsep 0 --output-format json | tee token.json
```
Roles: crear/borrar VMs · leer el estado del nodo · subir la ISO de cloud-init y
reservar espacio · conectar las VMs al puente.

`env.sh` (con el secreto que acaba de imprimir el comando anterior):
```bash
export PROXMOX_URL="https://TU-PROXMOX:8006"
export PROXMOX_TOKEN="capmox@pve!capi"
export PROXMOX_SECRET="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

## 2. Instalar Cluster API + el proveedor de Proxmox
```bash
curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.10.10/clusterctl-linux-amd64 \
  -o /usr/local/bin/clusterctl && chmod +x /usr/local/bin/clusterctl

source env.sh && source cluster.env
clusterctl init --core cluster-api:v1.10.10 --bootstrap kubeadm:v1.10.10 \
  --control-plane kubeadm:v1.10.10 --infrastructure proxmox:v0.7.7 --ipam in-cluster:v1.0.3

kubectl get pods -A | grep -E "capi-|capmox"
```

## 3. La plantilla que se clona
```bash
bash plantilla-k8s.sh      # léelo antes: crea la VM 9500 y la convierte en plantilla
qm config 9500             # sin ide2 (cloud-init de Proxmox), con agent=1
```

## 4. Generar el manifiesto del clúster
```bash
cat cluster.env
clusterctl generate cluster pyme --infrastructure proxmox:v0.7.7 \
  --kubernetes-version v1.30.14 --control-plane-machine-count 1 --worker-machine-count 1 > pyme.yaml
grep -n "^kind:" pyme.yaml
bash ajustes.sh            # los 4 retoques para un servidor real
```

## 5. Aplicar: las VMs nacen solas
```bash
kubectl apply -f pyme.yaml
kubectl get machines
qm list | grep pyme
clusterctl describe cluster pyme      # el árbol de diagnóstico
```

## 6. Entrar en el clúster nuevo y ponerle red de pods
```bash
clusterctl get kubeconfig pyme > pyme.kubeconfig
KUBECONFIG=pyme.kubeconfig kubectl get nodes            # NotReady: falta el CNI
KUBECONFIG=pyme.kubeconfig kubectl apply -f \
  https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
KUBECONFIG=pyme.kubeconfig kubectl get nodes
```

## 7. Escalar y destruir
```bash
kubectl scale machinedeployment pyme-workers --replicas=2
qm list | grep pyme

kubectl delete cluster pyme      # se lleva las VMs y libera las IPs
qm list | grep pyme
```
