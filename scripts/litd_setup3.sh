#!/bin/bash

# Script de Instalación de litd para Ubuntu
# Este script automatiza la instalación y configuración de Lightning Terminal (litd)

set -e  # Salir inmediatamente si un comando termina con un estado distinto de cero

# Variables
USER_HOME=$(eval echo ~${SUDO_USER:-$USER})
LIT_CONF_DIR="$USER_HOME/.lit"
LIT_CONF_FILE="$LIT_CONF_DIR/lit.conf"
LND_DIR="$USER_HOME/.lnd"
WALLET_PASSWORD_FILE="$LND_DIR/wallet_password"
GO_VERSION="1.21.0"
NODE_VERSION="22.x"  # Asegurar una versión estable y número par
LITD_VERSION="v0.14.0-alpha"  # Versión de litd a instalar
SERVICE_FILE="/etc/systemd/system/litd.service"

# Descomentar la configuración de desbloqueo de la billetera en el archivo de configuración
echo "[+] Descomentando la configuración de desbloqueo de la billetera en el archivo de configuración..."
sed -i "s|^#lnd.wallet-unlock-password-file=/home/ubuntu/.lnd/wallet_password|lnd.wallet-unlock-password-file=$USER_HOME/.lnd/wallet_password|" $LIT_CONF_FILE
sed -i "s|^#lnd.wallet-unlock-allow-create=true|lnd.wallet-unlock-allow-create=true|" $LIT_CONF_FILE

echo "[+] La configuración de desbloqueo de la billetera se ha habilitado en $LIT_CONF_FILE."

# Encontrar la ruta al binario litd usando el shell de inicio de sesión original del usuario
LITD_PATH=$(sudo -i -u "${SUDO_USER:-$USER}" which litd)

# Asegurar que se encuentre el binario litd
if [[ -z "$LITD_PATH" ]]; then
  echo "[!] Error: no se encontró el binario 'litd' en PATH."
  exit 1
fi

# Crear archivo de servicio systemd
if [[ ! -f "$SERVICE_FILE" ]]; then
  echo "[+] Creando archivo de servicio systemd para litd..."
  cat <<EOF > $SERVICE_FILE
[Unit]
Description=Demonio de Terminal Litd
Requires=bitcoind.service
After=bitcoind.service

[Service]
ExecStart=$LITD_PATH litd

User=${SUDO_USER:-$USER}
Group=${SUDO_USER:-$USER}

Type=simple
Restart=always
RestartSec=120

[Install]
WantedBy=multi-user.target
EOF
else
  echo "[!] El archivo de servicio Systemd ya existe. Omitiendo la creación."
fi

# Habilitar, recargar e iniciar el servicio systemd
systemctl enable litd
systemctl daemon-reload
if ! systemctl is-active --quiet litd; then
  systemctl start litd
  echo "[+] El servicio litd se inició."
else
  echo "[!] El servicio litd ya se está ejecutando."
fi

cat <<'EOF'

[+] ¡Demonio de Lightning Terminal (litd) compilado, configurado y servicio habilitado con éxito!


             ________________________________________________
            /                                                \
           |    _________________________________________     |
           |   |                                         |    |
           |   |       ___(                        )     |    |
           |   |      (                          _)      |    |
           |   |     (_                       __))       |    |
           |   |       ((                _____)          |    |
           |   |         (______________)                |    |
           |   |           __/    _/                     |    |
           |   |          /     /                        |    |
           |   |       _/    _/                          |    |
           |   |      /   _/                             |    |
           |   |     | _/                                |    |
           |   |     /                                   |    |
           |   |_________________________________________|    |
           |                                                  |
            \_________________________________________________/
                   \___________________________________/
                ___________________________________________
             _-'    .-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-.  --- `-_
          _-'.-.-. .---.-.-.-.-.-.-.-.-.-.-.-.-.-.-.--.  .-.-.`-_
       _-'.-.-.-. .---.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-`__`. .-.-.-.`-_
    _-'.-.-.-.-. .-----.-.-.-.-.-.-.-.-.-.-.-.-.-.-.-----. .-.-.-.-.`-_
 _-'.-.-.-.-.-. .---.-. .-------------------------. .-.---. .---.-.-.-.`-_
:-------------------------------------------------------------------------:
`---._.-------------------------------------------------------------._.---'

[+] ¡Su nodo Litd ahora está en funcionamiento!
EOF
