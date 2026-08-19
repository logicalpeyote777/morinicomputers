#!/bin/bash
# verificar-informe.sh <informe.txt> — ¿lo ha tocado alguien desde que se firmó?
# Morini Computers · github.com/logicalpeyote777/morinicomputers
INF="$1"
openssl pkeyutl -verify -rawin -pubin -inkey /root/audit/auditoria.pub \
        -in "$INF" -sigfile "$INF.sig"
