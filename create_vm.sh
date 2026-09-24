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

VM_NAME="$1"
OVS_NAME="$2"
VLAN_ID="$3"
VNC_INPUT="$4"

if [ "$#" -ne 4 ]; then
    echo "Uso:"
    echo "$0 <VM_NAME> <OVS_NAME> <VLAN_ID> <VNC>"
    exit 1
fi

BASE_IMG="cirros-0.5.1-x86_64-disk.img"
BASE_URL="http://download.cirros-cloud.net/0.5.1/$BASE_IMG"

VM_IMG="${VM_NAME}.qcow2"

# Linux limita los nombres de interfaces a 15 caracteres
TAP_NAME=$(echo "tap_${VM_NAME}" | cut -c1-15)

PIDFILE="/tmp/${VM_NAME}.pid"

# Determinar display VNC
if [ "$VNC_INPUT" -ge 5900 ]; then
    VNC_DISPLAY=$((VNC_INPUT - 5900))
else
    VNC_DISPLAY="$VNC_INPUT"
fi

VNC_TCP_PORT=$((5900 + VNC_DISPLAY))

# Validaciones
if ! sudo ovs-vsctl br-exists "$OVS_NAME"; then
    echo "ERROR: El OVS $OVS_NAME no existe."
    exit 1
fi

if [ -f "$PIDFILE" ]; then
    PID=$(sudo cat "$PIDFILE")
    if sudo kill -0 "$PID" 2>/dev/null; then
        echo "ERROR: La VM $VM_NAME ya está ejecutándose."
        exit 1
    else
        sudo rm -f "$PIDFILE"
    fi
fi

echo "===== Creando VM $VM_NAME ====="

# Descargar imagen base
if [ ! -f "$BASE_IMG" ]; then
    echo "[INFO] Descargando imagen base CirrOS..."
    wget "$BASE_URL"
else
    echo "[OK] Imagen base disponible."
fi

# Crear overlay QCOW2
if [ ! -f "$VM_IMG" ]; then
    qemu-img create \
        -f qcow2 \
        -F qcow2 \
        -b "$BASE_IMG" \
        "$VM_IMG"

    echo "[OK] Overlay $VM_IMG creado."
else
    echo "[OK] Overlay $VM_IMG ya existe."
fi

# Crear TAP
if ! ip link show "$TAP_NAME" >/dev/null 2>&1; then

    sudo ip tuntap add \
        mode tap \
        name "$TAP_NAME"

    sudo ip link set \
        dev "$TAP_NAME" up

    echo "[OK] TAP $TAP_NAME creada."
fi

# Conectar TAP al OVS
if ! sudo ovs-vsctl port-to-br \
    "$TAP_NAME" >/dev/null 2>&1; then
    sudo ovs-vsctl add-port \
        "$OVS_NAME" \
        "$TAP_NAME" \
        tag="$VLAN_ID"
else
    sudo ovs-vsctl set port \
        "$TAP_NAME" \
        tag="$VLAN_ID"
fi

echo "[OK] TAP conectada a VLAN $VLAN_ID."

# Generar MAC válida a partir de VLAN + VNC
MAC_VLAN=$(printf "%02x" $((VLAN_ID % 256)))
MAC_VNC=$(printf "%02x" $((VNC_DISPLAY % 256)))

MAC="52:54:00:00:${MAC_VLAN}:${MAC_VNC}"

# Ejecutar VM
sudo qemu-system-x86_64 \
    -enable-kvm \
    -name "$VM_NAME" \
    -vnc 0.0.0.0:"$VNC_DISPLAY" \
    -netdev tap,id=net0,ifname="$TAP_NAME",script=no,downscript=no \
    -device e1000,netdev=net0,mac="$MAC" \
    -drive file="$VM_IMG",format=qcow2 \
    -pidfile "$PIDFILE" \
    -daemonize

echo
echo "===== VM creada correctamente ====="
echo "VM:          $VM_NAME"
echo "Disco:       $VM_IMG"
echo "TAP:         $TAP_NAME"
echo "OVS:         $OVS_NAME"
echo "VLAN:        $VLAN_ID"
echo "MAC:         $MAC"
echo "VNC display: :$VNC_DISPLAY"
echo "Puerto TCP:  $VNC_TCP_PORT"
echo "PID:         $(sudo cat "$PIDFILE")"