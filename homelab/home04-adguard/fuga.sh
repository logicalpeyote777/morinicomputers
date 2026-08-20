#!/bin/bash
# El agujero que nadie te cuenta: el navegador puede resolver por su cuenta,
# por HTTPS, sin pasar por tu DNS.
set -u
echo "  1) por TU DNS:"
echo -n "     doubleclick.net -> "
dig +short @10.10.10.10 doubleclick.net A | head -1 | grep -qE '^[0-9]' \
  && dig +short @10.10.10.10 doubleclick.net A | head -1 || echo "NXDOMAIN (bloqueado)"
echo "  2) por DNS-sobre-HTTPS, saltandoselo:"
echo -n "     doubleclick.net -> "
curl -s -H 'accept: application/dns-json' \
  'https://cloudflare-dns.com/dns-query?name=doubleclick.net&type=A' | jq -r '.Answer[0].data'
echo
echo "  3) la senal que apaga el DoH automatico del navegador:"
echo -n "     use-application-dns.net -> "
dig +noall +comments @10.10.10.10 use-application-dns.net A | grep -o 'status: [A-Z]*'
