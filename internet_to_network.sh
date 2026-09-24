#!/bin/bash

# ============================================================
# internet_to_network.sh
#
# Parámetros:
#   $1 VLAN ID
#   $2 Red en formato CIDR
#
# Comando:
#   bash internet_to_network.sh <VLAN_ID> <CIDR>
#
# Funciones:
#   - Habilitar acceso a Internet para una VLAN.
#   - Configurar NAT mediante ens3.
#   - Permitir tráfico de salida y retorno.
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

if ! ip link show "$GW_IF" >/dev/null 2>&1; then
    echo "ERROR: No existe $GW_IF."
    exit 1
fi

# Configurar NAT
sudo iptables -t nat -C POSTROUTING \
    -s "$CIDR" \
    -o "$WAN_IF" \
    -j MASQUERADE 2>/dev/null || \
sudo iptables -t nat -A POSTROUTING \
    -s "$CIDR" \
    -o "$WAN_IF" \
    -j MASQUERADE

# Permitir salida hacia Internet
sudo iptables -C FORWARD \
    -i "$GW_IF" \
    -o "$WAN_IF" \
    -s "$CIDR" \
    -j ACCEPT 2>/dev/null || \
sudo iptables -A FORWARD \
    -i "$GW_IF" \
    -o "$WAN_IF" \
    -s "$CIDR" \
    -j ACCEPT

# Permitir tráfico de retorno
sudo iptables -C FORWARD \
    -i "$WAN_IF" \
    -o "$GW_IF" \
    -d "$CIDR" \
    -m conntrack \
    --ctstate ESTABLISHED,RELATED \
    -j ACCEPT 2>/dev/null || \
sudo iptables -A FORWARD \
    -i "$WAN_IF" \
    -o "$GW_IF" \
    -d "$CIDR" \
    -m conntrack \
    --ctstate ESTABLISHED,RELATED \
    -j ACCEPT

echo "[OK] Internet habilitado para:"
echo "     VLAN $VLAN_ID"
echo "     Red $CIDR"