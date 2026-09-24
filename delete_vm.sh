#!/bin/bash

# ============================================================
# delete_vm.sh
#
# Parámetros:
#   $1 Nombre de la VM
#   $2 Nombre del bridge OVS
#   $3 VLAN ID
#   $4 Display o puerto VNC
#
# Comando:
#   bash delete_vm.sh <VM_NAME> <OVS_NAME> <VLAN_ID> <VNC>
#
# Funciones:
#   - Detener y eliminar una VM.
#   - Eliminar su interfaz TAP del OVS.
#   - Eliminar su disco QCOW2.
#   - Eliminar la imagen base si ninguna otra VM la utiliza.
# ============================================================

set -e

VM_NAME="$1"
OVS_NAME="$2"
VLAN_ID="$3"
VNC_INPUT="$4"

if [ "$#" -ne 4 ]; then
    echo "Uso: $0 <VM_NAME> <OVS_NAME> <VLAN_ID> <VNC>"
    exit 1
fi

BASE_IMG="cirros-0.5.1-x86_64-disk.img"
VM_IMG="${VM_NAME}.qcow2"
TAP_NAME=$(echo "tap_${VM_NAME}" | cut -c1-15)
PIDFILE="/tmp/${VM_NAME}.pid"

echo "===== Eliminando VM $VM_NAME ====="

# Detener QEMU
if [ -f "$PIDFILE" ]; then
    PID=$(sudo cat "$PIDFILE")
    if sudo kill -0 "$PID" 2>/dev/null; then
        sudo kill "$PID"
        for i in {1..5}; do
            sudo kill -0 "$PID" 2>/dev/null || break
            sleep 1
        done
        sudo kill -0 "$PID" 2>/dev/null && sudo kill -9 "$PID" || true
    fi
    sudo rm -f "$PIDFILE"
else
    PID=$(pgrep -f "qemu-system-x86_64.*-name $VM_NAME" || true)
    [ -n "$PID" ] && sudo kill "$PID" || true
fi

# Eliminar TAP de OVS y Linux
if sudo ovs-vsctl port-to-br "$TAP_NAME" >/dev/null 2>&1; then
    sudo ovs-vsctl del-port "$OVS_NAME" "$TAP_NAME"
fi

if ip link show "$TAP_NAME" >/dev/null 2>&1; then
    sudo ip link set dev "$TAP_NAME" down 2>/dev/null || true
    sudo ip tuntap del mode tap name "$TAP_NAME"
fi

# Eliminar disco de la VM
if [ -f "$VM_IMG" ]; then
    rm -f "$VM_IMG"
    echo "[OK] Disco $VM_IMG eliminado."
fi

# Verificar si otras VMs utilizan la imagen base
DELTAS=0
for IMG in *.qcow2; do
    [ -e "$IMG" ] || continue
    BACKING=$(qemu-img info "$IMG" 2>/dev/null |
        awk -F': ' '/backing file:/ {print $2}' |
        awk '{print $1}')
    if [ -n "$BACKING" ] &&
       [ "$(basename "$BACKING")" = "$BASE_IMG" ]; then
        DELTAS=$((DELTAS + 1))
    fi
done

# Eliminar imagen base si ya no es utilizada
if [ "$DELTAS" -eq 0 ]; then
    if [ -f "$BASE_IMG" ]; then
        rm -f "$BASE_IMG"
        echo "[OK] Imagen base eliminada."
    fi
else
    echo "[INFO] La imagen base se conserva: $DELTAS VM(s) aún dependen de ella."
fi
echo "===== VM $VM_NAME eliminada correctamente ====="