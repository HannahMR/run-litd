#!/bin/bash

# litd Neutrino Setup — Final Step
# Tested on Ubuntu 24.04
#
# Enables wallet auto-unlock and registers litd as a systemd service.
# Run this after completing wallet creation with `lncli --network=<network> create`.
#
# Unlike litd_setup3.sh, this service has no bitcoind dependency.

set -e

# Variables
USER_HOME=$(eval echo ~${SUDO_USER:-$USER})
LIT_CONF_FILE="$USER_HOME/.lit/lit.conf"
SERVICE_FILE="/etc/systemd/system/litd.service"

# Check root
if [[ $EUID -ne 0 ]]; then
    echo "[-] This script must be run as root. Use sudo."
    exit 1
fi

# Check config file exists
if [[ ! -f "$LIT_CONF_FILE" ]]; then
    echo "[-] lit.conf not found at $LIT_CONF_FILE."
    echo "    Run neutrino_setup_binary.sh first."
    exit 1
fi

# Enable wallet auto-unlock
echo "[+] Enabling wallet auto-unlock in lit.conf..."
sed -i "s|^#lnd.wallet-unlock-password-file=.*|lnd.wallet-unlock-password-file=$USER_HOME/.lnd/wallet_password|" $LIT_CONF_FILE
sed -i "s|^#lnd.wallet-unlock-allow-create=true|lnd.wallet-unlock-allow-create=true|" $LIT_CONF_FILE
echo "[+] Wallet auto-unlock enabled."

# Find litd binary
LITD_PATH=$(sudo -i -u "${SUDO_USER:-$USER}" which litd)
if [[ -z "$LITD_PATH" ]]; then
    echo "[-] litd binary not found in PATH. Check that /usr/local/bin is in PATH."
    exit 1
fi

# Create systemd service (no bitcoind dependency — Neutrino handles its own Bitcoin connection)
if [[ ! -f "$SERVICE_FILE" ]]; then
    echo "[+] Creating systemd service for litd..."
    cat <<EOF > $SERVICE_FILE
[Unit]
Description=Lightning Terminal Daemon (Neutrino)
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=$LITD_PATH

User=${SUDO_USER:-$USER}
Group=${SUDO_USER:-$USER}

Type=simple
Restart=always
RestartSec=120

[Install]
WantedBy=multi-user.target
EOF
    echo "[+] Systemd service file created."
else
    echo "[!] Systemd service file already exists. Skipping creation."
fi

# Enable and start service
systemctl enable litd
systemctl daemon-reload
if ! systemctl is-active --quiet litd; then
    systemctl start litd
    echo "[+] litd service started."
else
    echo "[!] litd service is already running."
fi

cat <<'EOF'

[+] Lightning Terminal Daemon (litd) with Neutrino is now running as a systemd service!

    Verify with:
      systemctl status litd
      journalctl -fu litd
      lncli --network=<signet|mainnet> getinfo

    Neutrino syncs from peers — allow a few minutes for synced_to_chain: true.

EOF
