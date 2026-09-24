#!/bin/bash

# ============================================================
# routing_networks.sh
#
# Parámetros:
#   $1 VLAN ID 1
#   $2 VLAN ID 2
#
# Comando:
#   bash routing_networks.sh <VLAN_ID_1> <VLAN_ID_2>
#
# Funciones:
#   - Habilitar comunicación entre dos VLAN.
#   - Permitir tráfico en ambos sentidos.
# ============================================================

set -e

VLAN1="$1"
VLAN2="$2"

IF1="gw_vlan${VLAN1}"
IF2="gw_vlan${VLAN2}"

if [ "$#" -ne 2 ]; then
    echo "Uso: $0 <VLAN_ID_1> <VLAN_ID_2>"
    exit 1
fi

if ! ip link show "$IF1" >/dev/null 2>&1; then
    echo "ERROR: No existe $IF1."
    exit 1
fi

if ! ip link show "$IF2" >/dev/null 2>&1; then
    echo "ERROR: No existe $IF2."
    exit 1
fi

# VLAN1 -> VLAN2
sudo iptables -C FORWARD \
    -i "$IF1" \
    -o "$IF2" \
    -j ACCEPT 2>/dev/null || \
sudo iptables -A FORWARD \
    -i "$IF1" \
    -o "$IF2" \
    -j ACCEPT

# VLAN2 -> VLAN1
sudo iptables -C FORWARD \
    -i "$IF2" \
    -o "$IF1" \
    -j ACCEPT 2>/dev/null || \
sudo iptables -A FORWARD \
    -i "$IF2" \
    -o "$IF1" \
    -j ACCEPT

echo "[OK] Routing habilitado:"
echo "     VLAN $VLAN1 <--> VLAN $VLAN2"