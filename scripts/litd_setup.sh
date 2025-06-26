#!/bin/bash

# Script de Instalación de litd para Ubuntu
# Este script automatiza la instalación y configuración de Lightning Terminal (litd)

set -e  # Salir si algún comando falla

# Variables
USER_HOME=$(eval echo ~${SUDO_USER:-$USER})
GO_VERSION="1.21.0"
NODE_VERSION="22.x"  # Versión estable de Node.js
LITD_VERSION="v0.14.0-alpha"  # Versión de litd a instalar

# Asegurar que el directorio Go existe
if [[ ! -d "$USER_HOME/go/bin" ]]; then
  mkdir -p "$USER_HOME/go/bin"
fi

echo "[+] Asegurando que $GO_BIN_DIR sea propiedad de $(id -nu ${SUDO_USER:-$USER}):$(id -ng ${SUDO_USER:-$USER})..."
sudo chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} "$USER_HOME/go"

# Instalar Go
echo "[+] Verificando si Go $GO_VERSION está instalado..."
if command -v go &> /dev/null && [[ $(go version | awk '{print $3}' | cut -c3-) == "$GO_VERSION" ]]; then
  echo "[+] Go $GO_VERSION ya está instalado. Omitiendo la instalación."
else
  echo "[+] Instalando Go $GO_VERSION..."
  wget -q "https://golang.org/dl/go$GO_VERSION.linux-amd64.tar.gz" -O go.tar.gz
  if [[ -f go.tar.gz ]]; then
    sudo tar -C /usr/local -xzf go.tar.gz
    rm go.tar.gz

    # Actualizar .profile para el usuario que invoca
    sudo -u ${SUDO_USER:-$USER} bash -c "
    if ! grep -q 'export GOPATH=$USER_HOME/go' $USER_HOME/.profile; then
      echo 'export GOPATH=$USER_HOME/go' >> $USER_HOME/.profile
    fi
    if ! grep -q 'export PATH=$USER_HOME/go/bin:/usr/local/go/bin:\$PATH' $USER_HOME/.profile; then
      echo 'export PATH=$USER_HOME/go/bin:/usr/local/go/bin:\$PATH' >> $USER_HOME/.profile
    fi
    "

    # Exportar variables para la sesión actual
    export GOPATH="$USER_HOME/go"
    export PATH="$USER_HOME/go/bin:/usr/local/go/bin:$PATH"

    echo "[+] ¡Go $GO_VERSION instalado con éxito!"
  else
    echo "[-] No se pudo descargar el archivo tar de Go. Saliendo."
    exit 1
  fi
fi

# Instalar Node.js
echo "[+] Verificando si Node.js está instalado..."
if command -v node &> /dev/null && [[ $(node -v | grep -oP '\d+' | head -1) -ge 18 ]]; then
  echo "[+] Node.js ya está instalado. Versión: $(node -v)"
else
  echo "[+] Instalando Node.js (versión estable)..."
  sudo apt-get install -y curl
  curl -fsSL https://deb.nodesource.com/setup_$NODE_VERSION -o nodesource_setup.sh
  sudo -E bash nodesource_setup.sh
  sudo apt-get install -y nodejs
  echo "[+] Node.js instalado con éxito. Versión: $(node -v)"
fi

# Instalar Yarn
echo "[+] Verificando si Yarn está instalado..."
if command -v yarn &> /dev/null; then
  echo "[+] Yarn ya está instalado. Versión: $(yarn --version)"
else
  echo "[+] Instalando Yarn..."
  sudo npm install -g yarn
  echo "[+] Yarn instalado con éxito. Versión: $(yarn --version)"
fi

echo "[+] ¡Instalación y configuración completadas!"
echo "[+] Por favor, verifique que GoLang, NodeJS y Yarn estén instalados correctamente."
echo "[+] Luego, finalice la sesión de bash actual e inicie una nueva antes de ejecutar el siguiente script."
