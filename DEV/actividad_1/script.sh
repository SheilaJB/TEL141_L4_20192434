#!/bin/bash

# Actividad 1: REDES AISLADAS CON DHCP Y CON SALIDA A INTERNET

# Server_1: contiene contenedores docker 
# Server_2: contiene VMs 

# VLAN_ID - CIDR - Gateway
# VALN100 - 192.168.0.0/24 - 192.168.0.1
# VALN200 - 192.168.2.0/24 - 192.168.2.1

# Generar un archivo .log que almacene las validaciones y otro para errores


S1="ubuntu@10.0.10.1"
S2="ubuntu@10.0.10.2"
S3="ubuntu@10.0.10.3"

LOG="actividad1.log"
ERRLOG="actividad1_error.log"

