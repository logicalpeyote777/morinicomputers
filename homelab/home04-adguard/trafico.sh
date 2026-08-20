#!/bin/bash
# La casa en veinte segundos: cada equipo preguntando lo que pregunta de verdad
# cuando nadie lo esta tocando.
set -u
q() { dig +short +time=2 +tries=1 -b "$1" @10.10.10.10 "$2" A >/dev/null 2>&1; }
for d in graph.facebook.com app-measurement.com device-metrics-us.amazon.com jellyfin.org; do q 10.10.10.21 "$d"; done
for d in adjust.com appsflyer.com branch.io wikipedia.org;                                  do q 10.10.10.22 "$d"; done
for d in tiktok.com pagead2.googlesyndication.com mixpanel.com debian.org;                  do q 10.10.10.23 "$d"; done
for d in sentry.io scorecardresearch.com github.com docker.com;                             do q 10.10.10.24 "$d"; done
echo "  16 consultas, 4 equipos de la casa"
