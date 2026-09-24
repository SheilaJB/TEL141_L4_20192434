#!/bin/bash

# ============================================================
# no_internet_to_network.sh
#
# Parámetros:
#   $1 VLAN ID
#   $2 Red en formato CIDR
#
# Comando:
#   bash no_internet_to_network.sh <VLAN_ID> <CIDR>
#
# Funciones:
#   - Deshabilitar el acceso a Internet de una VLAN.
#   - Eliminar las reglas NAT y FORWARD asociadas.
# ============================================================

set -e

VLAN_ID="$1"
CIDR="$2"

GW_IF="gw_vlan${VLAN_ID}"
WAN_IF="ens3"

if [ "$#" -ne 2 ]; then
    echo "Uso: $0 <VLAN_ID> <CIDR>"
    exit 1
fi

# Eliminar MASQUERADE
if sudo iptables -t nat -C POSTROUTING -s "$CIDR" -o "$WAN_IF" -j MASQUERADE 2>/dev/null; then
    sudo iptables -t nat -D POSTROUTING -s "$CIDR" -o "$WAN_IF" -j MASQUERADE
fi

# Eliminar VLAN -> Internet
if sudo iptables -C FORWARD -i "$GW_IF" -o "$WAN_IF" -s "$CIDR" -j ACCEPT 2>/dev/null; then
    sudo iptables -D FORWARD -i "$GW_IF" -o "$WAN_IF" -s "$CIDR" -j ACCEPT
fi

# Eliminar retorno
if sudo iptables -C FORWARD \
    -i "$WAN_IF" \
    -o "$GW_IF" \
    -d "$CIDR" \
    -m conntrack \
    --ctstate ESTABLISHED,RELATED \
    -j ACCEPT 2>/dev/null; then

    sudo iptables -D FORWARD \
        -i "$WAN_IF" \
        -o "$GW_IF" \
        -d "$CIDR" \
        -m conntrack \
        --ctstate ESTABLISHED,RELATED \
        -j ACCEPT
fi

echo "[OK] Internet deshabilitado para VLAN $VLAN_ID."