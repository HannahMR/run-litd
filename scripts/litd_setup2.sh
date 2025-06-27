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
GO_VERSION="1.23.9"
NODE_VERSION="24.x"  # Ensure an even-numbered, stable release
LITD_VERSION="v0.15.0-alpha"  # Version of litd to be installed
SERVICE_FILE="/etc/systemd/system/litd.service"


# Clone and build litd
echo "[+] Checking if Lightning Terminal is already installed..."
if [[ -f "$USER_HOME/go/bin/litd" ]]; then
    echo "[+] Lightning Terminal (litd) is already installed. Skipping build."
else
    echo "[+] litd not found in $USER_HOME/go/bin. Proceeding with installation."

    echo "[+] Ensuring $USER_HOME/go directory exists and is owned by the current user..."
    if [[ -d "$USER_HOME/go" ]]; then
        echo "[+] Directory $USER_HOME/go already exists."
    else
        echo "[+] Creating $USER_HOME/go directory..."
        mkdir -p "$USER_HOME/go"
        echo "[+] Directory $USER_HOME/go created successfully."
    fi
    echo "[+] Ensuring proper ownership of $USER_HOME/go..."
    sudo chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} "$USER_HOME/go"

    # Ensure required build tools are installed
    echo "[+] Checking for required build tools..."
    if ! command -v make &> /dev/null; then
        echo "[+] 'make' not found. Installing build-essential package..."
        sudo apt update
        sudo apt install build-essential -y
    else
        echo "[+] 'make' is already installed."
    fi

    echo "[+] Checking if Lightning Terminal repository already exists..."
    if [[ -d "$USER_HOME/lightning-terminal" ]]; then
        echo "[!] Repository already exists. Using existing directory."
        cd "$USER_HOME/lightning-terminal"
    else
        echo "[+] Cloning Lightning Terminal repository into $USER_HOME/lightning-terminal..."
        if git clone https://github.com/lightninglabs/lightning-terminal.git "$USER_HOME/lightning-terminal"; then
            echo "[+] Repository cloned successfully."
            cd "$USER_HOME/lightning-terminal"
            # Ensure Lightning Terminal directory ownership
            sudo chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} "$USER_HOME/lightning-terminal"
        else
            echo "[-] Failed to clone repository. Check your internet connection and permissions."
            exit 1
        fi
    fi

    echo "[+] Checking out version $LITD_VERSION..."
    if git checkout tags/$LITD_VERSION; then
        echo "[+] Checked out version $LITD_VERSION."
        echo "[+] Building litd... This might take a few minutes."
        export GOPATH=$USER_HOME/go
        export PATH=$USER_HOME/go/bin:/usr/local/go/bin:$PATH
        if make install && make go-install-cli; then
            echo "[+] litd successfully built and installed!"
            # Ensure binary ownership
            sudo chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} "$USER_HOME/go"
            
            # Ensure lightning-terminal directory ownership
            echo "[+] Ensuring proper ownership of $USER_HOME/lightning-terminal..."
            sudo chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} "$USER_HOME/lightning-terminal"
        else
            echo "[-] Failed to build and install litd. Check for errors in the build process."
            exit 1
        fi
    else
        echo "[-] Failed to checkout version $LITD_VERSION. Ensure the tag exists."
        exit 1
    fi
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
echo "Walk through the wallet creation process using $ lncli --network=[yournetwork] create."
echo "Use the already generated password which can be found via $ cat ~/.lnd/wallet_password"
echo "DO NOT FORGET TO PROPERLY BACKUP YOUR SEED!!!" 
echo "Then, stop litd, and run the next script... almost there!!!"