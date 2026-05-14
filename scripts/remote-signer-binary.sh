#!/bin/bash

# LND Remote Signer Setup Script for Ubuntu
# Assumes bitcoind is already installed and running.

set -e

# Variables
USER_HOME=$(eval echo ~${SUDO_USER:-$USER})
LND_DIR="$USER_HOME/.lnd"
LND_CONF_FILE="$LND_DIR/lnd.conf"
WALLET_PASSWORD_FILE="$LND_DIR/wallet_password"
SERVICE_FILE="/etc/systemd/system/lnd.service"
LND_VERSION="v0.20.1-beta"
BINARY_URL="https://github.com/lightningnetwork/lnd/releases/download/$LND_VERSION/lnd-linux-amd64-$LND_VERSION.tar.gz"
MANIFEST_URL="https://github.com/lightningnetwork/lnd/releases/download/$LND_VERSION/manifest-$LND_VERSION.txt"
SIGNATURE_URL="https://github.com/lightningnetwork/lnd/releases/download/$LND_VERSION/manifest-roasbeef-$LND_VERSION.sig"
KEY_ID="E4D85299674B2D31FAA1892E372CBD7633C61696"
KEY_SERVER="hkps://keyserver.ubuntu.com"
DOWNLOAD_DIR="/tmp/lnd_release_verification"

# Check if user is root
echo "[+] Checking for root privileges..."
if [[ $EUID -ne 0 ]]; then
  echo "[-] This script must be run as root. Use sudo."
  exit 1
fi

# Install LND from binary
echo "[+] Checking if LND is already installed..."
if [[ -f "/usr/local/bin/lnd" ]]; then
    echo "[+] LND is already installed. Skipping installation."
else
    echo "[+] LND not found in /usr/local/bin. Proceeding with installation."

    mkdir -p "$DOWNLOAD_DIR"
    cd "$DOWNLOAD_DIR" || { echo "[-] Failed to navigate to download directory."; exit 1; }

    echo "[+] Importing LND signing key..."
    gpg --keyserver "$KEY_SERVER" --recv-keys "$KEY_ID" || { echo "[-] Failed to import PGP key."; exit 1; }

    echo "[+] Downloading LND binary..."
    wget "$BINARY_URL" || { echo "[-] Failed to download binary."; exit 1; }

    echo "[+] Downloading manifest..."
    wget "$MANIFEST_URL" || { echo "[-] Failed to download manifest."; exit 1; }

    echo "[+] Downloading signature..."
    wget "$SIGNATURE_URL" || { echo "[-] Failed to download signature."; exit 1; }

    echo "[+] Verifying PGP signature..."
    gpg --verify "$(basename "$SIGNATURE_URL")" "$(basename "$MANIFEST_URL")" 2>&1 | grep "$KEY_ID" > /dev/null
    if [ $? -eq 0 ]; then
        echo "[+] Signature verification successful."
    else
        echo "[-] Signature verification failed. Exiting."
        exit 1
    fi

    echo "[+] Verifying SHA256 checksum..."
    grep "$(sha256sum "$(basename "$BINARY_URL")" | awk '{print $1}')" "$(basename "$MANIFEST_URL")" > /dev/null
    if [ $? -eq 0 ]; then
        echo "[+] SHA256 verification successful."
    else
        echo "[-] SHA256 verification failed. Exiting."
        exit 1
    fi

    echo "[+] Extracting LND binary..."
    tar -xzf "$DOWNLOAD_DIR/lnd-linux-amd64-$LND_VERSION.tar.gz" -C "$DOWNLOAD_DIR" --strip-components=1

    echo "[+] Installing binaries to /usr/local/bin..."
    sudo install -m 0755 -o root -g root "$DOWNLOAD_DIR/lnd" /usr/local/bin/lnd
    sudo install -m 0755 -o root -g root "$DOWNLOAD_DIR/lncli" /usr/local/bin/lncli

    echo "[+] Cleaning up temporary files..."
    rm -rf "$DOWNLOAD_DIR"

    cd "$USER_HOME"
    echo "[+] LND installed successfully!"
fi

# Ensure ~/.lnd directory exists
echo "[+] Ensuring the ~/.lnd directory exists..."
if [[ ! -d $LND_DIR ]]; then
    mkdir -p $LND_DIR
    sudo chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} $LND_DIR
    echo "[+] Created directory at $LND_DIR."
else
    echo "[!] Directory $LND_DIR already exists."
fi

# Generate wallet password
echo "[+] Checking if wallet password file exists..."
if [[ -f $WALLET_PASSWORD_FILE && -s $WALLET_PASSWORD_FILE ]]; then
    echo "[+] Wallet password file already exists. Skipping generation."
else
    echo "[+] Generating wallet password..."
    openssl rand -hex 21 > $WALLET_PASSWORD_FILE
    sudo chown ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} $WALLET_PASSWORD_FILE
    echo "[+] Wallet password saved to $WALLET_PASSWORD_FILE."
fi

# Configure LND
if [[ -f $LND_CONF_FILE && -s $LND_CONF_FILE ]]; then
    echo "[+] LND configuration file already exists. Skipping creation."
else
    echo "[+] Configuring LND as a remote signer..."

    while true; do
        read -p "Is your bitcoind backend running on mainnet or signet? [mainnet/signet]: " NETWORK
        NETWORK=$(echo "$NETWORK" | tr '[:upper:]' '[:lower:]')
        if [[ "$NETWORK" == "mainnet" || "$NETWORK" == "signet" ]]; then
            break
        else
            echo "[-] Invalid input. Please enter 'mainnet' or 'signet'."
        fi
    done

    read -s -p "Enter the RPC password for your bitcoind backend: " RPC_PASSWORD
    echo
    if [[ -z $RPC_PASSWORD ]]; then
        echo "[-] RPC password cannot be empty. Exiting."
        exit 1
    fi

    read -p "Enter the IP address of this remote signer node (used by the watch-only node to connect): " SIGNER_IP
    if [[ -z $SIGNER_IP ]]; then
        echo "[-] Signer IP cannot be empty. Exiting."
        exit 1
    fi

    read -p "Enter a node alias: " NODE_ALIAS

    cat <<EOF > $LND_CONF_FILE
[Application Options]
# Do not listen for p2p connections - remote signers don't need them
nolisten=true

# Listen for gRPC connections from the watch-only node
rpclisten=0.0.0.0:10009
restlisten=0.0.0.0:8080

# Include this node's IP in the TLS certificate so the watch-only node can verify it
tlsextraip=$SIGNER_IP

# Auto-unlock wallet on startup
wallet-unlock-password-file=$WALLET_PASSWORD_FILE
wallet-unlock-allow-create=true

debuglevel=info
alias=$NODE_ALIAS

[Bitcoin]
bitcoin.active=1
$( [[ "$NETWORK" == "signet" ]] && echo "bitcoin.signet=1" || echo "bitcoin.mainnet=1" )
bitcoin.node=bitcoind

[Bitcoind]
bitcoind.rpchost=127.0.0.1
bitcoind.rpcuser=bitcoinrpc
bitcoind.rpcpass=$RPC_PASSWORD
bitcoind.zmqpubrawblock=tcp://127.0.0.1:28332
bitcoind.zmqpubrawtx=tcp://127.0.0.1:28333
EOF

    sudo chown ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} $LND_CONF_FILE
    echo "[+] LND configuration file created at $LND_CONF_FILE."
fi

# Create systemd service file
if [[ ! -f "$SERVICE_FILE" ]]; then
    echo "[+] Creating systemd service file for lnd..."
    LND_PATH=$(which lnd)
    cat <<EOF > $SERVICE_FILE
[Unit]
Description=LND Remote Signer
Requires=bitcoind.service
After=bitcoind.service

[Service]
ExecStart=$LND_PATH

User=${SUDO_USER:-$USER}
Group=${SUDO_USER:-$USER}

Type=simple
Restart=always
RestartSec=120

[Install]
WantedBy=multi-user.target
EOF
    echo "[+] Systemd service file created at $SERVICE_FILE."
else
    echo "[!] Systemd service file already exists. Skipping creation."
fi

# Enable and start the service
systemctl enable lnd
systemctl daemon-reload
if ! systemctl is-active --quiet lnd; then
    systemctl start lnd
    echo "[+] lnd service started."
else
    echo "[!] lnd service is already running."
fi

cat <<"EOF"

[+] LND Remote Signer configured and started!

Next steps:

  1. Create your wallet (run as the non-root user):
       lncli --network=[mainnet|signet] create
     Use the password at: ~/.lnd/wallet_password
     BACK UP YOUR SEED PHRASE SECURELY - IT CANNOT BE RECOVERED.

  2. Export your account xpub for the watch-only node:
       lncli --network=[mainnet|signet] wallet accounts list

  3. Copy the TLS certificate to your watch-only node:
       ~/.lnd/tls.cert

  4. Bake a macaroon with signing permissions for the watch-only node:
       lncli --network=[mainnet|signet] bakemacaroon \
         signer:generate-key signer:sign-message signer:signoutputraw \
         walletkit:derivekey walletkit:deriveNextKey walletkit:signpsbt

EOF
