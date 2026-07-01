# tofprox2 — Monta tu nube en casa por menos de 200 €

Scripts del vídeo de Morini Computers (YouTube) «Deja de pagar la nube: monta la tuya por 200€».

## `coste-nube-vs-casa.sh`
Compara lo que cuesta la **nube** (por suscripción, cada mes) con un **servidor en casa**
(un mini-PC de 2ª mano + Proxmox gratis + la luz que gasta). Todos los precios son variables:

```bash
./coste-nube-vs-casa.sh [años] [€/mes nube] [precio PC] [vatios] [€/kWh]
# por defecto: 3 años, 27 €/mes, 180 €, 12 W, 0.15 €/kWh
./coste-nube-vs-casa.sh 5        # a 5 años
```

Solo fines educativos. Ajusta los precios a tu caso real.
