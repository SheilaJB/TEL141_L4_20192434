#!/bin/bash

# ============================================================
# no_routing_networks.sh
#
# Parámetros:
#   $1 VLAN ID 1
#   $2 VLAN ID 2
#
# Comando:
#   bash no_routing_networks.sh <VLAN_ID_1> <VLAN_ID_2>
#
# Funciones:
#   - Deshabilitar comunicación entre dos VLAN.
#   - Eliminar las reglas FORWARD en ambos sentidos.
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

# VLAN1 -> VLAN2
if sudo iptables -C FORWARD -i "$IF1" -o "$IF2" -j ACCEPT 2>/dev/null; then
    sudo iptables -D FORWARD -i "$IF1" -o "$IF2" -j ACCEPT
fi

# VLAN2 -> VLAN1
if sudo iptables -C FORWARD -i "$IF2" -o "$IF1" -j ACCEPT 2>/dev/null; then
    sudo iptables -D FORWARD -i "$IF2" -o "$IF1" -j ACCEPT
fi

echo "[OK] Routing eliminado:"
echo "     VLAN $VLAN1 X VLAN $VLAN2"