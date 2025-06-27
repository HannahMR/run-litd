#!/bin/bash

# Bitcoin Core Node Setup Script
# Tested on Ubuntu 24.04

set -e

# Configuration
USER_HOME=$(eval echo ~${SUDO_USER:-$USER})
BITCOIN_VERSION="29.0" 
BITCOIN_DIR="$USER_HOME/.bitcoin"
BITCOIN_CONF="$BITCOIN_DIR/bitcoin.conf"
RPC_AUTH=""
NETWORK=""
SERVICE_FILE="/etc/systemd/system/bitcoind.service"

# Check if user is root
echo "[+] Checking for root privileges..."
if [[ $EUID -ne 0 ]]; then
  echo "[-] This script must be run as root. Use sudo."
  exit 1
fi

# Update & Install dependencies
echo "[+] Updating system and installing dependencies..."
apt update && apt upgrade -y
apt install -y git build-essential libtool autotools-dev automake pkg-config libssl-dev libevent-dev \
    bsdmainutils libboost-system-dev libboost-filesystem-dev libboost-chrono-dev \
    libboost-program-options-dev libboost-test-dev libboost-thread-dev libminiupnpc-dev libzmq3-dev python3

# Clone Bitcoin Core repository
echo "[+] Checking for Bitcoin Core repository..."
if [[ ! -d "$USER_HOME/bitcoin" ]]; then
    echo "[+] Cloning Bitcoin Core repository using v$BITCOIN_VERSION into $USER_HOME..."
    git clone -b v$BITCOIN_VERSION https://github.com/bitcoin/bitcoin.git "$USER_HOME/bitcoin"
    sudo chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} "$USER_HOME/bitcoin"
else
    echo "[!] Bitcoin repository already exists. Skipping clone."
fi

# Navigate to the repository
cd "$USER_HOME/bitcoin/"

# Build Bitcoin Core from source
if [[ ! -f "/usr/local/bin/bitcoind" ]]; then
    echo "[+] Building Bitcoin Core. This may take a while..."
    ./autogen.sh
    ./configure CXXFLAGS="--param ggc-min-expand=1 --param ggc-min-heapsize=32768" --enable-cxx --with-zmq --without-gui \
        --disable-shared --with-pic --disable-tests --disable-bench --enable-upnp-default --disable-wallet
    echo "[+] This is the tedious part..."
    make -j "$(($(nproc)+1))"
    echo "[+] Almost done!"
    sudo make install
else
    echo "[!] bitcoind is already installed. Skipping build."
fi

# Head back to the user home directory
cd "$USER_HOME"

# Generate RPC password
echo "[+] Generating RPC password for other services to connect to bitcoind..."
wget -q https://raw.githubusercontent.com/bitcoin/bitcoin/master/share/rpcauth/rpcauth.py -O rpcauth.py
if [[ ! -f rpcauth.py ]]; then
    echo "[-] Failed to download RPC password generator. Exiting."
    exit 1
fi

# Run the RPC auth script
RPC_OUTPUT=$(python3 ./rpcauth.py bitcoinrpc)
RPC_AUTH=$(echo "$RPC_OUTPUT" | grep -oP '(?<=rpcauth=)\S+')
RPC_PASSWORD=$(echo "$RPC_OUTPUT" | awk '/Your password:/ {getline; print $1}' | tr -d '[:space:]')

# Display the password to the user
echo "[+] The following password has been generated for your RPC connection:"
echo "    Password: $RPC_PASSWORD"
echo "[!] Please save this password securely, as it will not be displayed again."

# Confirm user saved the password
read -p "Have you saved the password? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo "[-] Please save the password before continuing. Exiting setup."
    exit 1
fi

# Ask user to choose network
while true; do
    read -p "Do you want to run on mainnet or signet? (mainnet/signet): " NETWORK
    if [[ "$NETWORK" == "mainnet" || "$NETWORK" == "signet" ]]; then
        break
    else
        echo "[-] Invalid input. Please enter 'mainnet' or 'signet'."
    fi
done

# Create bitcoin.conf file
if [[ -f "$BITCOIN_CONF" ]]; then
    read -p "[!] bitcoin.conf already exists. Overwrite? (yes/no): " OVERWRITE
    if [[ "$OVERWRITE" != "yes" ]]; then
        echo "[!] Skipping bitcoin.conf creation."
    else
        echo "[+] Overwriting bitcoin.conf..."
    fi
fi

mkdir -p $BITCOIN_DIR
sudo chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} $BITCOIN_DIR
cat <<EOF > $BITCOIN_CONF
# Set the best block hash here:
# For v29.0 on Signet and good hash to try is... 
# 000000432adc32a0e79b9d5cf14bd32c7d37df2b96127c963cb20c69830464f4
#assumevalid=

# Run as a daemon mode without an interactive shell
daemon=1

# Set the number of megabytes of RAM to use, set to like 50% of available memory
dbcache=3000

# Add visibility into mempool and RPC calls for potential LND debugging
debug=mempool
debug=rpc

# Turn off the wallet, it won't be used
disablewallet=1

# Don't bother listening for peers
listen=0

# Constrain the mempool to the number of megabytes needed:
maxmempool=100

# Limit uploading to peers
maxuploadtarget=1000

# Turn off serving SPV nodes
nopeerbloomfilters=1
peerbloomfilters=0

# Don't accept deprecated multi-sig style
permitbaremultisig=0

# Set the RPC auth to what was set above
rpcauth=$RPC_AUTH

# Turn on the RPC server
server=1

# Reduce the log file size on restarts
shrinkdebuglog=1

# Set signet if needed
$( [[ "$NETWORK" == "signet" ]] && echo "signet=1" || echo "#signet=1" )

# Prune the blockchain. Example prune to 50GB
prune=50000

# Turn on transaction lookup index, if pruned node is off. 
txindex=0

# Turn on ZMQ publishing
zmqpubrawblock=tcp://127.0.0.1:28332
zmqpubrawtx=tcp://127.0.0.1:28333
EOF

# Set ownership of the configuration file to the user
sudo chown ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} $BITCOIN_CONF

# Inform user where the configuration file is located
echo "[+] Your bitcoin.conf file has been created at: $BITCOIN_CONF"

# Create systemd service file
if [[ ! -f "$SERVICE_FILE" ]]; then
    echo "[+] Creating systemd service file for bitcoind..."
    cat <<EOF > $SERVICE_FILE
[Unit]
Description=Bitcoin daemon
After=network.target

[Service]
ExecStart=/usr/local/bin/bitcoind
Type=forking
Restart=on-failure

User=${SUDO_USER:-$USER}
Group=sudo

[Install]
WantedBy=multi-user.target
EOF
else
    echo "[!] Systemd service file already exists. Skipping creation."
fi

# Enable, reload, and start systemd service
systemctl enable bitcoind
systemctl daemon-reload
if ! systemctl is-active --quiet bitcoind; then
    systemctl start bitcoind
    echo "[+] bitcoind service started."
else
    echo "[!] bitcoind service is already running."
fi

# Done
cat <<"EOF"

[+] Bitcoin Core built, configured, and service enabled successfully!

    ⠀⠀⠀⠀⠀⠀⠀⠀⣀⣤⣴⣶⣾⣿⣿⣿⣿⣷⣶⣦⣤⣀⠀⠀⠀⠀⠀⠀⠀⠀
    ⠀⠀⠀⠀⠀⣠⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⣄⠀⠀⠀⠀⠀
    ⠀⠀⠀⣠⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣄⠀⠀⠀
    ⠀⠀⣴⣿⣿⣿⣿⣿⣿⣿⠟⠿⠿⡿⠀⢰⣿⠁⢈⣿⣿⣿⣿⣿⣿⣿⣿⣦⠀⠀
    ⠀⣼⣿⣿⣿⣿⣿⣿⣿⣿⣤⣄⠀⠀⠀⠈⠉⠀⠸⠿⣿⣿⣿⣿⣿⣿⣿⣿⣧⠀
    ⢰⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡏⠀⠀⢠⣶⣶⣤⡀⠀⠈⢻⣿⣿⣿⣿⣿⣿⣿⡆
    ⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠃⠀⠀⠼⣿⣿⡿⠃⠀⠀⢸⣿⣿⣿⣿⣿⣿⣿⣷
    ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟⠀⠀⢀⣀⣀⠀⠀⠀⠀⢴⣿⣿⣿⣿⣿⣿⣿⣿⣿
    ⢿⣿⣿⣿⣿⣿⣿⣿⢿⣿⠁⠀⠀⣼⣿⣿⣿⣦⠀⠀⠈⢻⣿⣿⣿⣿⣿⣿⣿⡿
    ⠸⣿⣿⣿⣿⣿⣿⣏⠀⠀⠀⠀⠀⠛⠛⠿⠟⠋⠀⠀⠀⣾⣿⣿⣿⣿⣿⣿⣿⠇
    ⠀⢻⣿⣿⣿⣿⣿⣿⣿⣿⠇⠀⣤⡄⠀⣀⣀⣀⣀⣠⣾⣿⣿⣿⣿⣿⣿⣿⡟⠀
    ⠀⠀⠻⣿⣿⣿⣿⣿⣿⣿⣄⣰⣿⠁⢀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⠀⠀
    ⠀⠀⠀⠙⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠋⠀⠀⠀
    ⠀⠀⠀⠀⠀⠙⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⠋⠀⠀⠀⠀⠀
⠀    ⠀⠀⠀⠀⠀⠀⠀⠉⠛⠻⠿⢿⣿⣿⣿⣿⡿⠿⠟⠛⠉⠀⠀⠀⠀⠀⠀⠀⠀

[+] Your Bitcoin node is now up and running!
EOF
