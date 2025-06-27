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

LITD_VERSION="v0.15.0-alpha"  # Version of litd to be installed
BINARY_URL="https://github.com/lightninglabs/lightning-terminal/releases/download/$LITD_VERSION/lightning-terminal-linux-amd64-$LITD_VERSION.tar.gz"
SIGNATURE_URL="https://github.com/lightninglabs/lightning-terminal/releases/download/$LITD_VERSION/manifest-guggero-$LITD_VERSION.sig"
MANIFEST_URL="https://github.com/lightninglabs/lightning-terminal/releases/download/$LITD_VERSION/manifest-$LITD_VERSION.txt"
KEY_ID="F4FC70F07310028424EFC20A8E4256593F177720"
KEY_SERVER="hkps://keyserver.ubuntu.com"
DOWNLOAD_DIR="/tmp/litd_release_verification"


# Install litd from binary
echo "[+] Checking if Lightning Terminal is already installed..."
if [[ -f "/usr/local/bin/litd" ]]; then
    echo "[+] Lightning Terminal (litd) is already installed. Skipping installation."
else
    echo "[+] litd not found in /usr/local/bin. Proceeding with installation."

    # Create download directory
    mkdir -p "$DOWNLOAD_DIR"
    cd "$DOWNLOAD_DIR" || { echo "Failed to navigate to download directory."; exit 1; }
    echo "The current working directory is: $PWD"

    # Import Oli's key
    echo "Importing Oli's key..."
    gpg --keyserver "$KEY_SERVER" --recv-keys "$KEY_ID" || { echo "Failed to import PGP key."; exit 1; }

    # Download litd binary
    echo "Downloading binary..."
    wget "$BINARY_URL" || { echo "Failed to download binary."; exit 1; }

    echo "Downloading signature..."
    wget "$SIGNATURE_URL" || { echo "Failed to download signature."; exit 1; }

    echo "Downloading manifest..."
    wget "$MANIFEST_URL" || { echo "Failed to download manifest."; exit 1; }

    # Verify the release signature
    echo "Verifying signature..."
    gpg --verify "$(basename "$SIGNATURE_URL")" "$(basename "$MANIFEST_URL")" 2>&1 | grep "$KEY_ID" > /dev/null
    if [ $? -eq 0 ]; then
        echo "Signature verification successful."
    else
        echo "Signature verification failed or does not match the expected key ID: $KEY_ID."
        exit 1
    fi

    #Check SHASUM
    echo "Checking shasum..."
    grep "$(sha256sum "$(basename "$BINARY_URL")" | awk '{print $1}')" "$(basename "$MANIFEST_URL")" > /dev/null
    if [ $? -eq 0 ]; then
        echo "SHA256 hash verification successful."
    else
        echo "SHA256 hash verification failed."
        exit 1
    fi

    echo "[+] Extracting litd binary..."
    tar -xvzf "$DOWNLOAD_DIR/lightning-terminal-linux-amd64-$LITD_VERSION.tar.gz" -C "$DOWNLOAD_DIR" --strip-components=1

    echo "[+] Moving binaries to /usr/local/bin..."
    sudo mv "$DOWNLOAD_DIR"/* /usr/local/bin/

    echo "[+] Cleaning up temporary files..."
    rm -rf "$DOWNLOAD_DIR"

    echo "[+] litd successfully installed!"

    # Change back to the ubuntu user's home directory
    cd "$USER_HOME" || { echo "Failed to return to the user's home directory: $USER_HOME"; exit 1; }
fi

# Ensure ~/.lnd directory exists
echo "[+] Ensuring the ~/.lnd directory exists..."
if [[ ! -d $LND_DIR ]]; then
    mkdir -p $LND_DIR
    echo "[+] Created directory at $LND_DIR."
    # Ensure ~/.lnd directory is owned by the user
    echo "[+] Ensuring ownership of $LND_DIR..."
    sudo chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} $LND_DIR
    echo "[+] Ownership set to ${SUDO_USER:-$USER} for $LND_DIR."
else
    echo "[!] Directory $LND_DIR already exists."
fi

# Generate wallet password
echo "[+] Checking if wallet password file exists and is not empty..."
if [[ -f $WALLET_PASSWORD_FILE && -s $WALLET_PASSWORD_FILE ]]; then
    echo "[+] Wallet password file already exists and is not empty. Skipping generation."
else
    echo "[+] Generating wallet password..."
    openssl rand -hex 21 > $WALLET_PASSWORD_FILE
    if [[ -f $WALLET_PASSWORD_FILE ]]; then
        echo "[+] Wallet password generated and saved to $WALLET_PASSWORD_FILE."
        # Ensure wallet password file is owned by the user
        echo "[+] Ensuring ownership of $WALLET_PASSWORD_FILE..."
        sudo chown ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} $WALLET_PASSWORD_FILE
        echo "[+] Ownership set to ${SUDO_USER:-$USER} for $WALLET_PASSWORD_FILE."
    else
        echo "[-] Failed to generate wallet password. Exiting."
        exit 1
    fi
fi

# Configure litd
echo "[+] Step 4: Configuring Lightning Terminal (litd)..."

# Check if configuration directory exists
if [[ ! -d $LIT_CONF_DIR ]]; then
    mkdir -p $LIT_CONF_DIR
    echo "[+] Created configuration directory at $LIT_CONF_DIR."
    # Ensure .lit directory is owned by the user
    echo "[+] Ensuring ownership of $LIT_CONF_DIR..."
    sudo chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} $LIT_CONF_DIR
    echo "[+] Ownership set to ${SUDO_USER:-$USER} for $LIT_CONF_DIR."
else
    echo "[!] $LIT_CONF_DIR already exists."
fi

# Check if configuration file exists and is not empty
if [[ -f $LIT_CONF_FILE && -s $LIT_CONF_FILE ]]; then
    echo "[+] Configuration file already exists and is not empty. Skipping creation."
else
    echo "[+] Generating new configuration file..."

    read -p "Is your bitcoind backend running on mainnet or signet? [mainnet/signet]: " NETWORK
    NETWORK=$(echo "$NETWORK" | tr '[:upper:]' '[:lower:]')
    if [[ $NETWORK != "mainnet" && $NETWORK != "signet" ]]; then
        echo "[-] Invalid network selection. Please choose either 'mainnet' or 'signet'."
        exit 1
    fi

    read -s -p "Enter the RPC password for your bitcoind backend: " RPC_PASSWORD
    echo
    if [[ -z $RPC_PASSWORD ]]; then
        echo "[-] RPC password cannot be empty. Exiting."
        exit 1
    fi

    read -s -p "Enter a UI password for litd: " UI_PASSWORD
    echo
    if [[ -z $UI_PASSWORD ]]; then
        echo "[-] UI password cannot be empty. Exiting."
        exit 1
    fi

    read -p "Enter a Lightning Node alias: " NODE_ALIAS

    # Prepare the base configuration content
    CONFIG_CONTENT="# Litd Settings
enablerest=true
httpslisten=0.0.0.0:8443
uipassword=$UI_PASSWORD
network=$NETWORK
lnd-mode=integrated
pool-mode=disable
loop-mode=disable
autopilot.disable=true

# Bitcoin Configuration
lnd.bitcoin.active=1
lnd.bitcoin.node=bitcoind
lnd.bitcoind.rpchost=127.0.0.1
lnd.bitcoind.rpcuser=bitcoinrpc
lnd.bitcoind.rpcpass=$RPC_PASSWORD
lnd.bitcoind.zmqpubrawblock=tcp://127.0.0.1:28332
lnd.bitcoind.zmqpubrawtx=tcp://127.0.0.1:28333

# LND General Settings
#lnd.wallet-unlock-password-file=/home/ubuntu/.lnd/wallet_password
#lnd.wallet-unlock-allow-create=true
lnd.debuglevel=debug
lnd.alias=$NODE_ALIAS
lnd.maxpendingchannels=3
lnd.accept-keysend=true
lnd.accept-amp=true
lnd.rpcmiddleware.enable=true
lnd.autopilot.active=0

# LND Protocol Settings
lnd.protocol.simple-taproot-chans=true
lnd.protocol.simple-taproot-overlay-chans=true
lnd.protocol.option-scid-alias=true
lnd.protocol.zero-conf=true
lnd.protocol.custom-message=17

# Taproot Assets Settings
#taproot-assets.rpclisten=0.0.0.0:10029
#taproot-assets.allow-public-uni-proof-courier=true
#taproot-assets.allow-public-stats=true
#taproot-assets.universe.public-access=rw
#taproot-assets.experimental.rfq.skipacceptquotepricecheck=true
#taproot-assets.experimental.rfq.priceoracleaddress=rfqrpc://127.0.0.1:8095
#taproot-assets.experimental.rfq.priceoracleaddress=use_mock_price_oracle_service_promise_to_not_use_on_mainnet
#taproot-assets.experimental.rfq.mockoracleassetsperbtc=100000000"

    # Apply mainnet-specific logic
    if [[ $NETWORK == "mainnet" ]]; then
        CONFIG_CONTENT=$(echo "$CONFIG_CONTENT" | sed "/pool-mode=disable/s/^/# /" | sed "/loop-mode=disable/s/^/# /" | sed "/autopilot.disable=true/s/^/# /")
    fi

    # Write configuration content to file
    echo "$CONFIG_CONTENT" > $LIT_CONF_FILE
    echo "[+] Configuration file created at $LIT_CONF_FILE."

    # Ensure configuration file is owned by the user
    echo "[+] Ensuring ownership of $LIT_CONF_FILE..."
    sudo chown ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} $LIT_CONF_FILE
    echo "[+] Ownership set to ${SUDO_USER:-$USER} for $LIT_CONF_FILE."
fi

echo "Now you have a task! Start litd with $ litd, do so as the user who will be running litd."
echo "In a new tab..."
echo "Walk through the wallet creation process using $ lncli --network=[yournetwork] create."
echo "Use the already generated password which can be found via $ cat ~/.lnd/wallet_password"
echo "DO NOT FORGET TO PROPERLY BACKUP YOUR SEED!!!" 
echo "Then, stop litd, and run the next script... almost there!!!"