#!/bin/bash

# litd Installation Script for Ubuntu
# This script automates the installation and configuration of Lightning Terminal (litd)

set -e  # Exit immediately if a command exits with a non-zero status

# Variables
USER_HOME=$(eval echo ~${SUDO_USER:-$USER})
LIT_CONF_DIR="$USER_HOME/.lit"
LIT_CONF_FILE="$LIT_CONF_DIR/lit.conf"
LND_DIR="$USER_HOME/.lnd"
WALLET_PASSWORD_FILE="$LND_DIR/wallet_password"
SERVICE_FILE="/etc/systemd/system/litd.service"

# Uncomment wallet unlock settings in the configuration file
echo "[+] Uncommenting wallet unlock settings in the configuration file..."
sed -i "s|^#lnd.wallet-unlock-password-file=/home/ubuntu/.lnd/wallet_password|lnd.wallet-unlock-password-file=$USER_HOME/.lnd/wallet_password|" $LIT_CONF_FILE
sed -i "s|^#lnd.wallet-unlock-allow-create=true|lnd.wallet-unlock-allow-create=true|" $LIT_CONF_FILE

echo "[+] Wallet unlock settings have been enabled in $LIT_CONF_FILE."   

# Find the path to the litd binary using the original user’s login shell
LITD_PATH=$(sudo -i -u "${SUDO_USER:-$USER}" which litd)

# Ensure litd binary is found
if [[ -z "$LITD_PATH" ]]; then
    echo "[!] Error: 'litd' binary not found in PATH."
    exit 1
fi

# Create systemd service file
if [[ ! -f "$SERVICE_FILE" ]]; then
    echo "[+] Creating systemd service file for litd..."
    cat <<EOF > $SERVICE_FILE
[Unit]
Description=Litd Terminal Daemon
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
    echo "[!] Systemd service file already exists. Skipping creation."
fi

# Enable, reload, and start systemd service
systemctl enable litd
systemctl daemon-reload
if ! systemctl is-active --quiet litd; then
    systemctl start litd
    echo "[+] litd service started."
else
    echo "[!] litd service is already running."
fi

cat <<'EOF'

[+] Lightning Terminal Daemon (litd) built, configured, and service enabled successfully!


             ________________________________________________
            /                                                \
           |    _________________________________________     |
           |   |                                         |    |
           |   |       ___(                        )     |    |
           |   |      (                          _)      |    |
           |   |     (_                       __))       |    |
           |   |       ((                _____)          |    |
           |   |         (_________)----'                |    |
           |   |              _/  /                      |    |
           |   |             /  _/                       |    |
           |   |           _/  /                         |    |
           |   |          / __/                          |    |
           |   |        _/ /                             |    |
           |   |       /__/                              |    |
           |   |      /'                                 |    |
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

[+] Your Litd node is now up and running!
EOF