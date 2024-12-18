#!/bin/bash

# Bitcoin Core Node Setup Script
# Tested on Ubuntu 20.04 / 22.04

set -e

# Configuration
BITCOIN_DIR="$HOME/.bitcoin"
BITCOIN_CONF="$BITCOIN_DIR/bitcoin.conf"
RPC_AUTH=""
NETWORK=""

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
echo "[+] Cloning Bitcoin Core repository..."
git clone -b v27.2 https://github.com/bitcoin/bitcoin.git

# Navigate to the repository
echo "[+] Navigating to the Bitcoin Core repository..."
cd bitcoin/

# Build Bitcoin Core from source
echo "[+] Running build process. This may take a while..."
./autogen.sh
./configure CXXFLAGS="--param ggc-min-expand=1 --param ggc-min-heapsize=32768" --enable-cxx --with-zmq --without-gui \
    --disable-shared --with-pic --disable-tests --disable-bench --enable-upnp-default --disable-wallet
make -j "$(($(nproc)+1))"
sudo make install

# Generate RPC password
echo "[+] Generating RPC password for other services to connect to bitcoind..."
wget -q https://raw.githubusercontent.com/bitcoin/bitcoin/master/share/rpcauth/rpcauth.py -O rpcauth.py
if [[ ! -f rpcauth.py ]]; then
    echo "[-] Failed to download RPC password generator. Exiting."
    exit 1
fi

# Run the RPC auth script
RPC_OUTPUT=$(python3 ./rpcauth.py bitcoinrpc)
RPC_AUTH=$(echo "$RPC_OUTPUT" | grep -oP 'rpcauth=\S+')
RPC_PASSWORD=$(echo "$RPC_OUTPUT" | grep -oP '(?<=Your password: )\S+')

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
echo "[+] Creating the bitcoin.conf file at $BITCOIN_CONF..."
mkdir -p $BITCOIN_DIR
cat <<EOF > $BITCOIN_CONF
# Set the best block hash here:
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
$RPC_AUTH

# Turn on the RPC server
server=1

# Reduce the log file size on restarts
shrinkdebuglog=1

# Set signet if needed
$( [[ "$NETWORK" == "signet" ]] && echo "signet=1" || echo "#signet=1" )

# Prune the blockchain. Example prune to 80GB
#prune=80000

# Turn on transaction lookup index, if pruned node is off. 
txindex=0

# Turn on ZMQ publishing
zmqpubrawblock=tcp://127.0.0.1:28332
zmqpubrawtx=tcp://127.0.0.1:28333
EOF

# Inform user where the configuration file is located
echo "[+] Your bitcoin.conf file has been created at: $BITCOIN_CONF"
echo "[!] You can review or modify this file as needed."

# Create systemd service file
echo "[+] Creating systemd service file for bitcoind..."
SERVICE_FILE="/etc/systemd/system/bitcoind.service"
cat <<EOF > $SERVICE_FILE
[Unit]
Description=Bitcoin daemon
After=network.target

[Service]
ExecStart=/usr/local/bin/bitcoind
Type=forking
Restart=on-failure

# Run as ubuntu:ubuntu
User=ubuntu
Group=sudo

[Install]
WantedBy=multi-user.target
EOF

# Enable, reload, and start systemd service
echo "[+] Enabling and starting the bitcoind service..."
systemctl enable bitcoind
systemctl daemon-reload
systemctl start bitcoind

# Done
cat <<"EOF"

[+] Bitcoin Core built, configured, and service enabled successfully!

        .--.
       |o_o |
       |:_/ |
      //   \ \
     (|     | )
    /'\_   _/`\
    \___)=(___/

[+] Your Bitcoin node is now up and running!
EOF
