#!/bin/bash
# medir.sh <etiqueta> - mide la latencia REAL dentro de la VM de tiempo real.
# cyclictest despierta un hilo de prioridad 90 cada 200 microsegundos durante 40
# segundos y apunta cuanto se retrasa cada despertar. El numero que importa es
# Max: el PEOR caso. Un TPV, una centralita VoIP o un PLC se rompen con el peor
# caso, no con la media.
VM=192.168.1.54
ET="${1:-medida}"
echo ">>> midiendo 40 s dentro de la VM (prioridad 90, cada 200 us)..."
ssh -o StrictHostKeyChecking=no luca@$VM \
  "sudo cyclictest --mlockall --priority=90 --interval=200 --duration=40 --quiet" \
  | tee "/root/rt/$ET.txt"
