#!/bin/bash

# ============================================================
# init_master.sh
#
# Parámetros:
#   1.Ingresar los interfces que se deben conectar al br-int
#
# Comando:
#   bash init_master.sh <Interfaz/Interfaces>
#
# Funciones:
#   - Crear br-int si es que no existe.
#   - Conectar las interfaces indicadas a br-int.
#   - Activar IPv4 forwarding.
#   - Configurar política FORWARD por defecto en DROP.
# ============================================================

# por si falla el bash 
set -e

BRIDGE="br-int"

if [ "$#" -lt 1 ]; then
    echo "Uso: $0 <interfaz1> [interfaz2 ...]"
    exit 1
fi
echo "===== Inicializando ====="

# Crear br-int si no existe y lo mantenemos Activa
sudo ovs-vsctl --may-exist add-br "$BRIDGE"
sudo ip link set dev "$BRIDGE" up

# Conectar interfaces recibidas
for INTERFAZ in "$@"; do

    # Protección de la interfaz ens3
    if [ "$INTERFAZ" = "ens3" ]; then
        echo "ERROR: La interfaz ens3 pertenece a la red de management. No debe conectarse al bridge $BRIDGE."
        exit 1
    fi

    # Verificar que la interfaz exista
    if ! ip link show "$INTERFAZ" >/dev/null 2>&1; then
        echo "ERROR: La interfaz $INTERFAZ no existe."
        exit 1
    fi

    sudo ovs-vsctl --may-exist add-port "$BRIDGE" "$INTERFAZ"
    sudo ip link set dev "$INTERFAZ" up

    echo "[OK] $INTERFAZ conectada a $BRIDGE."
done

# Activar IPv4 forwarding
sudo sysctl -w net.ipv4.ip_forward=1

# Política por defecto restrictiva
sudo iptables -P FORWARD DROP

echo
echo "===== Configurado correctamente init_master.sh ====="
sudo ovs-vsctl show
echo
sysctl net.ipv4.ip_forward
echo
sudo iptables -L FORWARD -n -v