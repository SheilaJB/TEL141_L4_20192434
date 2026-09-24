#!/bin/bash

# ============================================================
# delete_network_vlan.sh
#
# Parámetros:
#   $1 VLAN ID
#
# Comando:
#   bash delete_network_vlan.sh <VLAN_ID>
#
# Funciones:
#   - Eliminar una red VLAN.
#   - Eliminar su gateway.
#   - Eliminar el servicio DHCP asociado, si existe.
# ============================================================
set -e

VLAN_ID="$1"
BRIDGE="br-int"
GW_IF="gw_vlan${VLAN_ID}"
NS_NAME="ns-dhcp-vlan${VLAN_ID}"
DHCP_PORT="dhcp_v${VLAN_ID}"

if [ "$#" -lt 1 ]; then
    echo "Uso: $0 <VLAN_ID>"
    exit 1
fi

echo "===== Eliminando Red VLAN $VLAN_ID ====="

# 1. Detener dnsmasq y eliminar namespace si existe
PID_FILE="/run/dnsmasq_vlan${VLAN_ID}.pid"
if [ -f "$PID_FILE" ]; then
    PID=$(sudo cat "$PID_FILE")
    sudo kill "$PID" 2>/dev/null || true
    sudo rm -f "$PID_FILE"
fi

if sudo ip netns list | grep -qw "$NS_NAME"; then
    echo "[INFO] Eliminando namespace $NS_NAME..."
    sudo ip netns del "$NS_NAME" 2>/dev/null || true
fi

# 2. Eliminar puerto DHCP de OVS si existe
if sudo ovs-vsctl port-to-br "$DHCP_PORT" >/dev/null 2>&1; then
    echo "[INFO] Eliminando puerto $DHCP_PORT de $BRIDGE..."
    sudo ovs-vsctl del-port "$BRIDGE" "$DHCP_PORT" 2>/dev/null || true
fi

# 3. Eliminar interfaz interna gateway de OVS si existe
if sudo ovs-vsctl port-to-br "$GW_IF" >/dev/null 2>&1; then
    echo "[INFO] Eliminando puerto $GW_IF de $BRIDGE..."
    sudo ovs-vsctl del-port "$BRIDGE" "$GW_IF" 2>/dev/null || true
fi

# 4. Eliminar interfaz del kernel si quedó residual
if ip link show "$GW_IF" >/dev/null 2>&1; then
    sudo ip link delete "$GW_IF" 2>/dev/null || true
fi
echo "[OK] Red VLAN $VLAN_ID eliminada correctamente."
