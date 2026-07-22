#!/bin/bash
# plantilla-k8s.sh - Construye la PLANTILLA de Proxmox que usara Cluster API (CAPMOX)
# para clonar los nodos del clúster: Debian 12 cloud + containerd + kubeadm 1.30.
set -eux
VMID=9500
IP=192.168.1.190/24
GW=192.168.1.1
KVER=v1.30

qm stop $VMID 2>/dev/null || true
qm destroy $VMID --purge 2>/dev/null || true
qm clone 9000 $VMID --name plantilla-k8s --full 1 --storage vmstore
qm set $VMID --memory 2048 --cores 2 --agent enabled=1 --ipconfig0 ip=$IP,gw=$GW --ciuser luca
qm start $VMID

for i in $(seq 1 60); do ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 luca@192.168.1.190 true 2>/dev/null && break; sleep 5; done

ssh -o StrictHostKeyChecking=no luca@192.168.1.190 "sudo bash -s" <<"IN"
set -eux
export DEBIAN_FRONTEND=noninteractive
cloud-init status --wait
mkdir -p /etc/apt/keyrings
apt-get update
apt-get install -y qemu-guest-agent containerd apt-transport-https ca-certificates curl gpg
systemctl enable qemu-guest-agent
printf "overlay\nbr_netfilter\n" > /etc/modules-load.d/k8s.conf
modprobe overlay; modprobe br_netfilter
cat > /etc/sysctl.d/k8s.conf <<S
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
S
sysctl --system
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i "s/SystemdCgroup = false/SystemdCgroup = true/" /etc/containerd/config.toml
systemctl restart containerd; systemctl enable containerd
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
kubeadm config images pull
systemctl disable kubelet
# limpieza para que la plantilla nazca virgen en cada clon
cloud-init clean --logs --seed
truncate -s0 /etc/machine-id; rm -f /var/lib/dbus/machine-id
rm -f /etc/ssh/ssh_host_*
apt-get clean
IN

qm shutdown $VMID --timeout 120 || qm stop $VMID
sleep 5
# CAPMOX inyecta su propio cloud-init en ide0: fuera la unidad de Proxmox
qm set $VMID --delete ide2
qm template $VMID
qm config $VMID | grep -E "template|name|scsi0"
echo "PLANTILLA-OK $VMID"
