#!/bin/bash

# LND Remote Signer Setup Script for Ubuntu (build from source)
# Assumes bitcoind is already installed and running.

set -e

# Variables
USER_HOME=$(eval echo ~${SUDO_USER:-$USER})
LND_DIR="$USER_HOME/.lnd"
LND_CONF_FILE="$LND_DIR/lnd.conf"
WALLET_PASSWORD_FILE="$LND_DIR/wallet_password"
SERVICE_FILE="/etc/systemd/system/lnd.service"
LND_VERSION="v0.20.1-beta"
GO_VERSION="1.23.9"

# Check if user is root
echo "[+] Checking for root privileges..."
if [[ $EUID -ne 0 ]]; then
  echo "[-] This script must be run as root. Use sudo."
  exit 1
fi

# Update & Install dependencies
echo "[+] Updating system and installing dependencies..."
apt-get update && apt-get upgrade -y
apt-get install -y git build-essential curl jq

# Install Go
echo "[+] Checking if Go $GO_VERSION is installed..."
if command -v go &> /dev/null && [[ $(go version | awk '{print $3}' | cut -c3-) == "$GO_VERSION" ]]; then
    echo "[+] Go $GO_VERSION is already installed. Skipping installation."
else
    echo "[+] Installing Go $GO_VERSION..."
    wget "https://golang.org/dl/go$GO_VERSION.linux-amd64.tar.gz" -O go.tar.gz
    if [[ -f go.tar.gz ]]; then
        sudo tar -C /usr/local -xzf go.tar.gz
        rm go.tar.gz

        sudo -u ${SUDO_USER:-$USER} bash -c "
        if ! grep -q 'export GOPATH=$USER_HOME/go' $USER_HOME/.profile; then
            echo 'export GOPATH=$USER_HOME/go' >> $USER_HOME/.profile
        fi
        if ! grep -q 'export PATH=$USER_HOME/go/bin:/usr/local/go/bin:\$PATH' $USER_HOME/.profile; then
            echo 'export PATH=$USER_HOME/go/bin:/usr/local/go/bin:\$PATH' >> $USER_HOME/.profile
        fi
        "

        export GOPATH="$USER_HOME/go"
        export PATH="$USER_HOME/go/bin:/usr/local/go/bin:$PATH"

        echo "[+] Go $GO_VERSION installed successfully."
    else
        echo "[-] Failed to download Go tarball. Exiting."
        exit 1
    fi
fi

# Ensure go bin dir exists
if [[ ! -d "$USER_HOME/go/bin" ]]; then
    mkdir -p "$USER_HOME/go/bin"
fi
sudo chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} "$USER_HOME/go"

# Clone and build LND
echo "[+] Checking if LND is already installed..."
if [[ -f "$USER_HOME/go/bin/lnd" ]]; then
    echo "[+] LND is already installed. Skipping build."
else
    echo "[+] Checking for LND repository..."
    if [[ -d "$USER_HOME/lnd" ]]; then
        echo "[!] Repository already exists. Using existing directory."
        cd "$USER_HOME/lnd"
    else
        echo "[+] Cloning LND repository into $USER_HOME/lnd..."
        if git clone https://github.com/lightningnetwork/lnd.git "$USER_HOME/lnd"; then
            echo "[+] Repository cloned successfully."
            cd "$USER_HOME/lnd"
            sudo chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} "$USER_HOME/lnd"
        else
            echo "[-] Failed to clone repository. Exiting."
            exit 1
        fi
    fi

    echo "[+] Checking out version $LND_VERSION..."
    if git checkout tags/$LND_VERSION; then
        echo "[+] Building LND... This may take a few minutes."
        export GOPATH=$USER_HOME/go
        export PATH=$USER_HOME/go/bin:/usr/local/go/bin:$PATH
        if make install tags="walletrpc signrpc routerrpc chainrpc invoicesrpc"; then
            echo "[+] LND built and installed successfully."
            sudo chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} "$USER_HOME/go"
            sudo chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} "$USER_HOME/lnd"
        else
            echo "[-] Failed to build LND. Exiting."
            exit 1
        fi
    else
        echo "[-] Failed to checkout version $LND_VERSION. Exiting."
        exit 1
    fi
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
    chmod 600 $WALLET_PASSWORD_FILE
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
    LND_PATH="$USER_HOME/go/bin/lnd"
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

# Detect network from config
if grep -q "bitcoin.signet=1" "$LND_CONF_FILE" 2>/dev/null; then
    NETWORK="signet"
else
    NETWORK="mainnet"
fi

MACAROON_PATH="$LND_DIR/data/chain/bitcoin/$NETWORK/admin.macaroon"
LNCLI="$USER_HOME/go/bin/lncli"
SEED_FILE="$LND_DIR/seed_phrase.txt"
XPUB_FILE="$LND_DIR/accounts.json"
SIGNER_MACAROON="$LND_DIR/signer.macaroon"
TIMEOUT=180

if [[ -f "$MACAROON_PATH" ]]; then
    echo "[!] Wallet already initialized. Skipping wallet setup."
else
    # Wait for TLS cert
    echo "[+] Waiting for LND to generate TLS certificate..."
    ELAPSED=0
    while [[ ! -f "$LND_DIR/tls.cert" ]]; do
        sleep 2
        ELAPSED=$((ELAPSED + 2))
        if [[ $ELAPSED -ge $TIMEOUT ]]; then
            echo "[-] Timed out waiting for TLS certificate. Exiting."
            exit 1
        fi
    done
    echo "[+] TLS certificate ready."

    # Wait for REST API
    echo "[+] Waiting for LND REST API..."
    ELAPSED=0
    while ! curl -sf --cacert "$LND_DIR/tls.cert" https://localhost:8080/v1/state > /dev/null 2>&1; do
        sleep 2
        ELAPSED=$((ELAPSED + 2))
        if [[ $ELAPSED -ge $TIMEOUT ]]; then
            echo "[-] Timed out waiting for LND REST API. Exiting."
            exit 1
        fi
    done
    echo "[+] LND REST API is ready."

    # Generate seed
    echo "[+] Generating wallet seed..."
    SEED_JSON=$(curl -sf --cacert "$LND_DIR/tls.cert" https://localhost:8080/v1/genseed)
    if [[ -z "$SEED_JSON" ]]; then
        echo "[-] Failed to generate seed. Exiting."
        exit 1
    fi

    MNEMONIC=$(echo "$SEED_JSON" | jq -r '.cipher_seed_mnemonic | join(" ")')
    MNEMONIC_ARRAY=$(echo "$SEED_JSON" | jq -c '.cipher_seed_mnemonic')

    # Save seed to file (chmod 600 - readable only by owner)
    echo "$MNEMONIC" > "$SEED_FILE"
    chown ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} "$SEED_FILE"
    chmod 600 "$SEED_FILE"

    echo ""
    echo "============================================================"
    echo "  !! WALLET SEED PHRASE - BACK THIS UP IMMEDIATELY !!      "
    echo "  This is your ONLY recovery option if this node is lost.  "
    echo "============================================================"
    echo "$MNEMONIC"
    echo "============================================================"
    echo "  Saved to: $SEED_FILE  (chmod 600)"
    echo "  Once backed up, delete it:  shred -u $SEED_FILE"
    echo "============================================================"
    echo ""

    # Initialize wallet
    echo "[+] Initializing wallet..."
    WALLET_PASSWORD_B64=$(tr -d '\n' < "$WALLET_PASSWORD_FILE" | base64 -w 0)
    INIT_RESPONSE=$(curl -sf --cacert "$LND_DIR/tls.cert" \
        -X POST https://localhost:8080/v1/initwallet \
        -H 'Content-Type: application/json' \
        -d "{\"wallet_password\": \"$WALLET_PASSWORD_B64\", \"cipher_seed_mnemonic\": $MNEMONIC_ARRAY}")

    if [[ -z "$INIT_RESPONSE" ]]; then
        echo "[-] No response from initwallet endpoint. Exiting."
        exit 1
    fi
    if echo "$INIT_RESPONSE" | jq -e '.code' > /dev/null 2>&1; then
        echo "[-] Failed to initialize wallet: $(echo "$INIT_RESPONSE" | jq -r '.message')"
        exit 1
    fi
    echo "[+] Wallet initialized, waiting for unlock..."

    # Wait for admin macaroon (signals wallet is fully unlocked)
    ELAPSED=0
    while [[ ! -f "$MACAROON_PATH" ]]; do
        sleep 2
        ELAPSED=$((ELAPSED + 2))
        if [[ $ELAPSED -ge $TIMEOUT ]]; then
            echo "[-] Timed out waiting for wallet to unlock. Exiting."
            exit 1
        fi
    done
    echo "[+] Wallet unlocked."

    # Wait for gRPC server to be fully ready
    echo "[+] Waiting for LND gRPC to be ready..."
    ELAPSED=0
    while ! sudo -u ${SUDO_USER:-$USER} "$LNCLI" \
            --network="$NETWORK" \
            --macaroonpath="$MACAROON_PATH" \
            --tlscertpath="$LND_DIR/tls.cert" \
            getinfo > /dev/null 2>&1; do
        sleep 2
        ELAPSED=$((ELAPSED + 2))
        if [[ $ELAPSED -ge $TIMEOUT ]]; then
            echo "[-] Timed out waiting for LND gRPC. Exiting."
            exit 1
        fi
    done
    echo "[+] LND gRPC is ready."

    # Export xpub
    echo "[+] Exporting account xpub..."
    sudo -u ${SUDO_USER:-$USER} "$LNCLI" \
        --network="$NETWORK" \
        --macaroonpath="$MACAROON_PATH" \
        --tlscertpath="$LND_DIR/tls.cert" \
        wallet accounts list > "$XPUB_FILE"
    chown ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} "$XPUB_FILE"
    echo "[+] Account xpub saved to $XPUB_FILE"

    # Bake signing macaroon for the watch-only node
    echo "[+] Baking signing macaroon for watch-only node..."
    sudo -u ${SUDO_USER:-$USER} "$LNCLI" \
        --network="$NETWORK" \
        --macaroonpath="$MACAROON_PATH" \
        --tlscertpath="$LND_DIR/tls.cert" \
        bakemacaroon \
        signer:generate signer:read signer:write \
        uri:/walletrpc.WalletKit/DeriveNextKey \
        uri:/walletrpc.WalletKit/DeriveKey \
        uri:/walletrpc.WalletKit/SignPsbt \
        uri:/walletrpc.WalletKit/FinalizePsbt \
        --save_to "$SIGNER_MACAROON"
    chown ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} "$SIGNER_MACAROON"
    echo "[+] Signing macaroon saved to $SIGNER_MACAROON"
fi

cat <<"EOF"

[+] LND Remote Signer setup complete!

Copy these files to your watch-only node:
  - TLS certificate:   ~/.lnd/tls.cert
  - Signing macaroon:  ~/.lnd/signer.macaroon
  - Account xpub:      ~/.lnd/accounts.json

IMPORTANT: Back up your seed phrase and then delete it from disk:
  shred -u ~/.lnd/seed_phrase.txt

NOTE: To use lncli in this terminal session, run:
  source ~/.profile
Then you can run commands such as:
  lncli --network=<mainnet|signet> getinfo

EOF
