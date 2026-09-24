#!/bin/bash

# ============================================================
# create_network_vlan.sh
#
# Parámetros:
#   $1 VLAN ID
#   $2 Red en formato CIDR
#   $3 DHCP: yes | no
#   $4 Rango DHCP (solo si DHCP=yes)
#
# Comando:
#   bash create_network_vlan.sh <VLAN_ID> <CIDR> <yes|no> [RANGO_DHCP]
#
# Funciones:
#   - Crear una red VLAN sobre br-int.
#   - Configurar el gateway de la VLAN.
#   - Configurar DHCP si se solicita.
# ============================================================

set -e

VLAN_ID="$1"
CIDR="$2"
DHCP_ENABLE="$3"
DHCP_RANGE="${4:-}"

BRIDGE="br-int"
GW_IF="gw_vlan${VLAN_ID}"

# Validar parámetros y bridge
if [ "$#" -lt 3 ]; then
    echo "Uso: $0 <VLAN_ID> <CIDR> <yes|no> [RANGO_DHCP]"
    exit 1
fi

if ! sudo ovs-vsctl br-exists "$BRIDGE"; then
    echo "ERROR: El bridge $BRIDGE no existe."
    echo "Ejecute previamente init_master.sh."
    exit 1
fi

# Obtener datos de la red
NETWORK_IP=$(echo "$CIDR" | cut -d'/' -f1)
MASK=$(echo "$CIDR" | cut -d'/' -f2)

BASE=$(echo "$NETWORK_IP" | awk -F. '{print $1"."$2"."$3}')

GW_IP="${BASE}.1"
DHCP_IP="${BASE}.2"

echo "===== Configurando VLAN $VLAN_ID ====="
echo "Red:       $CIDR"
echo "Gateway:   $GW_IP/$MASK"
echo "DHCP:      $DHCP_ENABLE"

# Crear gateway de la VLAN
sudo ovs-vsctl --may-exist add-port "$BRIDGE" "$GW_IF" tag="$VLAN_ID" -- set interface "$GW_IF" type=internal
sudo ip link set dev "$GW_IF" up

if ! ip addr show dev "$GW_IF" | grep -q "$GW_IP/$MASK"; then
    sudo ip addr add "$GW_IP/$MASK" dev "$GW_IF"
fi

echo "[OK] Gateway $GW_IF → $GW_IP/$MASK"

# Verificar configuración DHCP
if [ "$DHCP_ENABLE" = "no" ]; then
    echo "[INFO] DHCP deshabilitado."
    exit 0
fi

if [ "$DHCP_ENABLE" != "yes" ]; then
    echo "ERROR: DHCP debe indicarse como yes o no."
    exit 1
fi

if [ -z "$DHCP_RANGE" ]; then
    echo "ERROR: Debe proporcionar rango DHCP."
    exit 1
fi

# Procesar rango DHCP
START_VALUE=$(echo "$DHCP_RANGE" | cut -d',' -f1)
END_VALUE=$(echo "$DHCP_RANGE" | cut -d',' -f2)

if echo "$START_VALUE" | grep -q '\.'; then
    START_IP="$START_VALUE"
else
    START_IP="${BASE}.${START_VALUE}"
fi

if echo "$END_VALUE" | grep -q '\.'; then
    END_IP="$END_VALUE"
else
    END_IP="${BASE}.${END_VALUE}"
fi

# Crear namespace para el servidor DHCP
NS_NAME="ns-dhcp-vlan${VLAN_ID}"
DHCP_PORT="dhcp_v${VLAN_ID}"

if ! sudo ip netns list | grep -qw "$NS_NAME"; then
    sudo ip netns add "$NS_NAME"
fi

# Conectar el DHCP a la VLAN
if ! sudo ovs-vsctl list-ports "$BRIDGE" | grep -qx "$DHCP_PORT"; then
    sudo ovs-vsctl add-port "$BRIDGE" "$DHCP_PORT" tag="$VLAN_ID" -- set interface "$DHCP_PORT" type=internal
    sudo ip link set "$DHCP_PORT" netns "$NS_NAME"
fi

# Configurar interfaz del servidor DHCP
sudo ip netns exec "$NS_NAME" ip link set lo up
sudo ip netns exec "$NS_NAME" ip link set "$DHCP_PORT" up

if ! sudo ip netns exec "$NS_NAME" ip addr show dev "$DHCP_PORT" | grep -q "$DHCP_IP/$MASK"; then
    sudo ip netns exec "$NS_NAME" ip addr add "$DHCP_IP/$MASK" dev "$DHCP_PORT"
fi

# Iniciar dnsmasq
PID_FILE="/run/dnsmasq_vlan${VLAN_ID}.pid"
LEASE_FILE="/var/lib/misc/dnsmasq_vlan${VLAN_ID}.leases"

if [ -f "$PID_FILE" ]; then
    PID=$(sudo cat "$PID_FILE")
    sudo kill "$PID" 2>/dev/null || true
    sudo rm -f "$PID_FILE"
fi

sudo ip netns exec "$NS_NAME" \
    dnsmasq \
    --interface="$DHCP_PORT" \
    --bind-interfaces \
    --pid-file="$PID_FILE" \
    --dhcp-leasefile="$LEASE_FILE" \
    --dhcp-range="$START_IP","$END_IP",12h \
    --dhcp-option=3,"$GW_IP"

echo
echo "===== DHCP configurado ====="
echo "Namespace:       $NS_NAME"
echo "Servidor DHCP:   $DHCP_IP"
echo "Rango DHCP:      $START_IP - $END_IP"
echo "Gateway:         $GW_IP"