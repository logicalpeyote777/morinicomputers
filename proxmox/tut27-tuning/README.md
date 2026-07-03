# tut27 — Exprime el rendimiento de tus VMs en Proxmox

Scripts del tutorial «Exprime el rendimiento de tus VMs: virtio, tipos de CPU,
ballooning y discos rápidos» de Morini Computers (YouTube).

## afinar-vm.sh

Aplica los 4 ajustes de rendimiento a cualquier VM:

```bash
bash afinar-vm.sh <vmid>
qm shutdown <vmid> && qm start <vmid>   # reinicia para aplicar
```

| Ajuste | Comando equivalente | Qué gana |
|---|---|---|
| CPU `host` | `qm set <vmid> --cpu host` | la VM ve tu CPU real (AES-NI, AVX…): en nuestra demo, cifrado ~18x más rápido |
| Disco | `qm set <vmid> --scsi0 <vol>,iothread=1,ssd=1,discard=on,cache=writeback` | más IOPS bajo carga |
| Red virtio | `qm set <vmid> --net0 virtio=<MAC>,bridge=<br>` | más ancho de banda, menos CPU |
| Ballooning | `qm set <vmid> --balloon <mitad-de-la-RAM>` | más VMs por servidor |

Matices: `cpu host` ata la VM a ese modelo de procesador (en clúster mixto usa un
modelo intermedio); `cache=writeback` solo con SAI/UPS detrás.

Medición usada en el vídeo: `openssl speed -elapsed -evp aes-256-gcm` (CPU) y
`fio --rw=randwrite --bs=4k --direct=1` (disco).
