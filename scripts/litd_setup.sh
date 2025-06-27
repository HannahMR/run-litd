#!/bin/bash

# litd Installation Script for Ubuntu
# This script automates the installation and configuration of Lightning Terminal (litd)

set -e  # Exit on any command failure

# Variables
USER_HOME=$(eval echo ~${SUDO_USER:-$USER})
GO_VERSION="1.23.9"
NODE_VERSION="24.x"  # Stable Node.js version
LITD_VERSION="v0.15.0-alpha"  # Version of litd to be installed

# Ensure Go directory exists
if [[ ! -d "$USER_HOME/go/bin" ]]; then
    mkdir -p "$USER_HOME/go/bin"
fi

echo "[+] Ensuring $GO_BIN_DIR is owned by $(id -nu ${SUDO_USER:-$USER}):$(id -ng ${SUDO_USER:-$USER})..."
sudo chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} "$USER_HOME/go"

# Install Go
echo "[+] Checking if Go $GO_VERSION is installed..."
if command -v go &> /dev/null && [[ $(go version | awk '{print $3}' | cut -c3-) == "$GO_VERSION" ]]; then
    echo "[+] Go $GO_VERSION is already installed. Skipping installation."
else
    echo "[+] Installing Go $GO_VERSION..."
    wget -q "https://golang.org/dl/go$GO_VERSION.linux-amd64.tar.gz" -O go.tar.gz
    if [[ -f go.tar.gz ]]; then
        sudo tar -C /usr/local -xzf go.tar.gz
        rm go.tar.gz

        # Update .profile for the invoking user
        sudo -u ${SUDO_USER:-$USER} bash -c "
        if ! grep -q 'export GOPATH=$USER_HOME/go' $USER_HOME/.profile; then
            echo 'export GOPATH=$USER_HOME/go' >> $USER_HOME/.profile
        fi
        if ! grep -q 'export PATH=$USER_HOME/go/bin:/usr/local/go/bin:\$PATH' $USER_HOME/.profile; then
            echo 'export PATH=$USER_HOME/go/bin:/usr/local/go/bin:\$PATH' >> $USER_HOME/.profile
        fi
        "

        # Export variables for the current session
        export GOPATH="$USER_HOME/go"
        export PATH="$USER_HOME/go/bin:/usr/local/go/bin:$PATH"

        echo "[+] Go $GO_VERSION installed successfully!"
    else
        echo "[-] Failed to download Go tarball. Exiting."
        exit 1
    fi
fi

# Install Node.js
echo "[+] Checking if Node.js is installed..."
if command -v node &> /dev/null && [[ $(node -v | grep -oP '\d+' | head -1) -ge 18 ]]; then
    echo "[+] Node.js is already installed. Version: $(node -v)"
else
    echo "[+] Installing Node.js (stable release)..."
    sudo apt-get install -y curl
    curl -fsSL https://deb.nodesource.com/setup_$NODE_VERSION -o nodesource_setup.sh
    sudo -E bash nodesource_setup.sh
    sudo apt-get install -y nodejs
    echo "[+] Node.js installed successfully. Version: $(node -v)"
fi

# Install Yarn
echo "[+] Checking if Yarn is installed..."
if command -v yarn &> /dev/null; then
    echo "[+] Yarn is already installed. Version: $(yarn --version)"
else
    echo "[+] Installing Yarn..."
    sudo npm install -g yarn
    echo "[+] Yarn installed successfully. Version: $(yarn --version)"
fi

echo "[+] Installation and configuration complete!"
echo "[+] Please verify that GoLang, NodeJS, and Yarn are properly installed."
echo "[+] Then, end the current bash session and start a new one before running the next script."
