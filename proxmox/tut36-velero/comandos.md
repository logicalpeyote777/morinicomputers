# tut36 — Backup y disaster recovery de Kubernetes con Velero (sobre Proxmox)

Comandos del tutorial, en orden. Lab: clúster K8s (k8s-cp/k8s-w1) en VMs de Proxmox;
MinIO (S3) corriendo FUERA del clúster, en el propio host Proxmox.

## 1) MinIO en el host (destino S3 fuera del clúster)
```bash
curl -fsSL -o /usr/local/bin/minio https://dl.min.io/server/minio/release/linux-amd64/minio
curl -fsSL -o /usr/local/bin/mc    https://dl.min.io/client/mc/release/linux-amd64/mc
chmod 0755 /usr/local/bin/minio /usr/local/bin/mc
mkdir -p /srv/minio
# servicio systemd (MINIO_ROOT_USER / MINIO_ROOT_PASSWORD) y luego:
mc alias set local http://127.0.0.1:9000 TU_USUARIO_MINIO TU_PASSWORD_MINIO
mc mb -p local/velero
```

## 2) La app de empresa (MariaDB + volumen persistente)
```bash
kubectl apply -f app.yaml
kubectl -n empresa wait --for=condition=ready pod -l app=facturas-db --timeout=220s
kubectl exec -i -n empresa deploy/facturas-db -- mariadb -uroot -pTU_PASSWORD facturacion < seed.sql
kubectl exec -n empresa deploy/facturas-db -- mariadb -uroot -pTU_PASSWORD facturacion \
  -e 'SELECT * FROM facturas; SELECT SUM(importe) AS total_facturado FROM facturas;'
```

## 3) Instalar Velero (CLI + server + node-agent)
```bash
VVER=v1.16.1
curl -fsSL -o velero.tgz "https://github.com/vmware-tanzu/velero/releases/download/$VVER/velero-$VVER-linux-amd64.tar.gz"
tar xzf velero.tgz && install -m0755 velero-$VVER-linux-amd64/velero /usr/local/bin/velero

velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.12.1 \
  --bucket velero \
  --secret-file ./credentials \
  --backup-location-config region=minio,s3ForcePathStyle=true,s3Url=http://IP_DE_TU_HOST:9000 \
  --use-node-agent \
  --use-volume-snapshots=false

kubectl get pods -n velero
velero backup-location get
```

## 4) Backup completo (recursos + contenido de los volúmenes)
```bash
velero backup create empresa-completo --include-namespaces empresa \
  --default-volumes-to-fs-backup --wait
velero backup get
mc ls -r local/velero/backups/empresa-completo/
```

## 5) El desastre y la restauración completa
```bash
kubectl delete namespace empresa            # el desastre
velero restore create --from-backup empresa-completo --wait
kubectl get pods,svc,pvc -n empresa
kubectl exec -n empresa deploy/facturas-db -c mariadb -- mariadb -uroot -pTU_PASSWORD facturacion \
  -e 'SELECT * FROM facturas;'
```

## 6) Backup diario programado con retención
```bash
velero schedule create backup-diario --schedule='0 3 * * *' \
  --include-namespaces empresa --default-volumes-to-fs-backup --ttl 168h0m0s
velero schedule get
```
