#!/bin/bash

# ============================================================
# init_worker.sh
#
# Parámetros:
#   1..N Interfaces de red de datos que se conectarán a br-int
#
# Comando:
#   bash init_worker.sh <Interfaz/Interfaces>
#
# Funciones:
#   - Crear br-int si no existe.
#   - Conectar las interfaces indicadas a br-int.

# ============================================================

# por si falla el bash 
set -e

BRIDGE="br-int"

if [ "$#" -lt 1 ]; then
    echo "Uso: $0 <interfaz1> [interfaz2 ...]"
    exit 1
fi

echo "===== Inicializando WORKER ====="

# Crear bridge
sudo ovs-vsctl --may-exist add-br "$BRIDGE"
sudo ip link set dev "$BRIDGE" up

# Conectar interfaces
for INTERFAZ in "$@"; do

    if [ "$INTERFAZ" = "ens3" ]; then
        echo "ERROR: La interfaz ens3 pertenece a la red de management. No debe conectarse al bridge $BRIDGE."
        exit 1
    fi

    if ! ip link show "$INTERFAZ" >/dev/null 2>&1; then
        echo "ERROR: La interfaz $INTERFAZ no existe."
        exit 1
    fi

    sudo ovs-vsctl --may-exist add-port "$BRIDGE" "$INTERFAZ"
    sudo ip link set dev "$INTERFAZ" up
    echo "[OK] $INTERFAZ conectada a $BRIDGE."
done

echo
echo "===== Configurado correctamente Worker ====="
sudo ovs-vsctl show