#!/bin/bash

# Script de Instalación de litd para Ubuntu
# Este script automatiza la instalación y configuración de Lightning Terminal (litd)

set -e  # Salir inmediatamente si un comando termina con un estado distinto de cero

# Variables
USER_HOME=$(eval echo ~${SUDO_USER:-$USER})
LIT_CONF_DIR="$USER_HOME/.lit"
LIT_CONF_FILE="$LIT_CONF_DIR/lit.conf"
LND_DIR="$USER_HOME/.lnd"
WALLET_PASSWORD_FILE="$LND_DIR/wallet_password"
GO_VERSION="1.21.0"
NODE_VERSION="22.x"  # Asegurar una versión estable y par
LITD_VERSION="v0.14.0-alpha"  # Versión de litd a instalar
SERVICE_FILE="/etc/systemd/system/litd.service"

# Clonar y construir litd
echo "[+] Verificando si Lightning Terminal ya está instalado..."
if [[ -f "$USER_HOME/go/bin/litd" ]]; then
  echo "[+] Lightning Terminal (litd) ya está instalado. Omitiendo la instalación."
else
  echo "[+] litd no se encontró en $USER_HOME/go/bin. Procediendo con la instalación."

  echo "[+] Asegurando que el directorio $USER_HOME/go existe y es propiedad del usuario actual..."
  if [[ -d "$USER_HOME/go" ]]; then
    echo "[+] El directorio $USER_HOME/go ya existe."
  else
    echo "[+] Creando el directorio $USER_HOME/go..."
    mkdir -p "$USER_HOME/go"
    echo "[+] Directorio $USER_HOME/go creado con éxito."
  fi
  echo "[+] Asegurando la propiedad adecuada de $USER_HOME/go..."
  sudo chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} "$USER_HOME/go"

  # Asegurar que las herramientas de construcción requeridas estén instaladas
  echo "[+] Verificando las herramientas de construcción requeridas..."
  if ! command -v make &> /dev/null; then
    echo "[+] 'make' no se encontró. Instalando el paquete build-essential..."
    sudo apt update
    sudo apt install build-essential -y
  else
    echo "[+] 'make' ya está instalado."
  fi

  echo "[+] Verificando si el repositorio de Lightning Terminal ya existe..."
  if [[ -d "$USER_HOME/lightning-terminal" ]]; then
    echo "[!] El repositorio ya existe. Usando el directorio existente."
    cd "$USER_HOME/lightning-terminal"
  else
    echo "[+] Clonando el repositorio de Lightning Terminal en $USER_HOME/lightning-terminal..."
    if git clone https://github.com/lightninglabs/lightning-terminal.git "$USER_HOME/lightning-terminal"; then
      echo "[+] Repositorio clonado con éxito."
      cd "$USER_HOME/lightning-terminal"
      # Asegurar la propiedad del directorio de Lightning Terminal
      sudo chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} "$USER_HOME/lightning-terminal"
      echo "[+] Propiedad establecida en ${SUDO_USER:-$USER} para $USER_HOME/lightning-terminal."
    else
      echo "[-] No se pudo clonar el repositorio. Verifique su conexión a Internet y permisos."
      exit 1
    fi
  fi

  echo "[+] Verificando la versión $LITD_VERSION..."
  if git checkout tags/$LITD_VERSION; then
    echo "[+] Versión $LITD_VERSION verificada."
    echo "[+] Construyendo litd... Esto puede tardar unos minutos."
    export GOPATH=$USER_HOME/go
    export PATH=$USER_HOME/go/bin:/usr/local/go/bin:$PATH
    if make install && make go-install-cli; then
      echo "[+] ¡litd compilado e instalado con éxito!"
      # Asegurar la propiedad del binario
      sudo chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} "$USER_HOME/go"
    else
      echo "[-] No se pudo compilar e instalar litd. Verifique si hay errores en el proceso de compilación."
      exit 1
    fi
  else
    echo "[-] No se pudo verificar la versión $LITD_VERSION. Asegúrese de que la etiqueta exista."
    exit 1
  fi
fi

# Asegurar que el directorio ~/.lnd existe
echo "[+] Asegurando que el directorio ~/.lnd existe..."
if [[ ! -d $LND_DIR ]]; then
  mkdir -p $LND_DIR
  echo "[+] Se creó el directorio en $LND_DIR."
  # Asegurar que el directorio ~/.lnd es propiedad del usuario
  echo "[+] Asegurando la propiedad de $LND_DIR..."
  sudo chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} $LND_DIR
  echo "[+] Propiedad establecida en ${SUDO_USER:-$USER} para $LND_DIR."
else
  echo "[!] El directorio $LND_DIR ya existe."
fi

# Generar contraseña de la billetera
echo "[+] Verificando si el archivo de contraseña de la billetera existe y no está vacío..."
if [[ -f $WALLET_PASSWORD_FILE && -s $WALLET_PASSWORD_FILE ]]; then
  echo "[+] El archivo de contraseña de la billetera ya existe y no está vacío. Omitiendo la generación."
else
  echo "[+] Generando contraseña de la billetera..."
  openssl rand -hex 21 > $WALLET_PASSWORD_FILE
  if [[ -f $WALLET_PASSWORD_FILE ]]; then
    echo "[+] Contraseña de la billetera generada y guardada en $WALLET_PASSWORD_FILE."
    # Asegurar que el archivo de contraseña de la billetera es propiedad del usuario
    echo "[+] Asegurando la propiedad de $WALLET_PASSWORD_FILE..."
    sudo chown ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} $WALLET_PASSWORD_FILE
    echo "[+] Propiedad establecida en ${SUDO_USER:-$USER} para $WALLET_PASSWORD_FILE."
  else
    echo "[-] No se pudo generar la contraseña de la billetera. Saliendo."
    exit 1
  fi
fi

# Configurar litd
echo "[+] Paso 4: Configurando Lightning Terminal (litd)..."

# Verificar si el directorio de configuración existe
if [[ ! -d $LIT_CONF_DIR ]]; then
  mkdir -p $LIT_CONF_DIR
  echo "[+] Se creó el directorio de configuración en $LIT_CONF_DIR."
  # Asegurar que el directorio .lit es propiedad del usuario
  echo "[+] Asegurando la propiedad de $LIT_CONF_DIR..."
  sudo chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} $LIT_CONF_DIR
  echo "[+] Propiedad establecida en ${SUDO_USER:-$USER} para $LIT_CONF_DIR."
else
  echo "[!] $LIT_CONF_DIR ya existe."
fi

# Verificar si el archivo de configuración existe y no está vacío
if [[ -f $LIT_CONF_FILE && -s $LIT_CONF_FILE ]]; then
  echo "[+] El archivo de configuración ya existe y no está vacío. Omitiendo la creación."
else
  echo "[+] Generando nuevo archivo de configuración..."

  read -p "¿Su backend de bitcoind se está ejecutando en mainnet o signet? [mainnet/signet]: " NETWORK
  NETWORK=$(echo "$NETWORK" | tr '[:upper:]' '[:lower:]')
  if [[ $NETWORK != "mainnet" && $NETWORK != "signet" ]]; then
    echo "[-] Selección de red inválida. Por favor, elija 'mainnet' o 'signet'."
    exit 1
  fi

  read -s -p "Ingrese la contraseña RPC para su backend de bitcoind: " RPC_PASSWORD
  echo
  if [[ -z $RPC_PASSWORD ]]; then
    echo "[-] La contraseña RPC no puede estar vacía. Saliendo."
    exit 1
  fi

  read -s -p "Ingrese una contraseña de UI para litd: " UI_PASSWORD
  echo
  if [[ -z $UI_PASSWORD ]]; then
    echo "[-] La contraseña de la UI no puede estar vacía. Saliendo."
    exit 1
  fi

  read -p "Ingrese un alias de nodo Lightning: " NODE_ALIAS

  # Preparar el contenido de configuración base
  CONFIG_CONTENT="# Configuración de Litd
enablerest=true
httpslisten=0.0.0.0:8443
uipassword=$UI_PASSWORD
network=$NETWORK
lnd-mode=integrated
pool-mode=disable
loop-mode=disable
autopilot.disable=true

# Configuración de Bitcoin
lnd.bitcoin.active=1
lnd.bitcoin.node=bitcoind
lnd.bitcoind.rpchost=127.0.0.1
lnd.bitcoind.rpcuser=bitcoinrpc
lnd.bitcoind.rpcpass=$RPC_PASSWORD
lnd.bitcoind.zmqpubrawblock=tcp://127.0.0.1:28332
lnd.bitcoind.zmqpubrawtx=tcp://127.0.0.1:28333

# Configuración General de LND
#lnd.wallet-unlock-password-file=/home/ubuntu/.lnd/wallet_password
#lnd.wallet-unlock-allow-create=true
lnd.debuglevel=debug
lnd.alias=$NODE_ALIAS
lnd.maxpendingchannels=3
lnd.accept-keysend=true
lnd.accept-amp=true
lnd.rpcmiddleware.enable=true
lnd.autopilot.active=0

# Configuración del Protocolo LND
lnd.protocol.simple-taproot-chans=true
lnd.protocol.simple-taproot-overlay-chans=true
lnd.protocol.option-scid-alias=true
lnd.protocol.zero-conf=true
lnd.protocol.custom-message=17

# Configuración de Activos Taproot
#taproot-assets.rpclisten=0.0.0.0:10029
#taproot-assets.allow-public-uni-proof-courier=true
#taproot-assets.allow-public-stats=true
#taproot-assets.universe.public-access=rw
#taproot-assets.experimental.rfq.skipacceptquotepricecheck=true
#taproot-assets.experimental.rfq.priceoracleaddress=rfqrpc://127.0.0.1:8095
#taproot-assets.experimental.rfq.priceoracleaddress=use_mock_price_oracle_service_promise_to_not_use_on_mainnet
#taproot-assets.experimental.rfq.mockoracleassetsperbtc=100000000"

  # Aplicar lógica específica de mainnet
  if [[ $NETWORK == "mainnet" ]]; then
    CONFIG_CONTENT=$(echo "$CONFIG_CONTENT" | sed "/pool-mode=disable/s/^/# /" | sed "/loop-mode=disable/s/^/# /" | sed "/autopilot.disable=true/s/^/# /")
  fi

  # Escribir contenido de configuración en el archivo
  echo "$CONFIG_CONTENT" > $LIT_CONF_FILE
  echo "[+] Archivo de configuración creado en $LIT_CONF_FILE."

  # Asegurar que el archivo de configuración es propiedad del usuario
  echo "[+] Asegurando la propiedad de $LIT_CONF_FILE..."
  sudo chown ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} $LIT_CONF_FILE
  echo "[+] Propiedad establecida en ${SUDO_USER:-$USER} para $LIT_CONF_FILE."
fi

echo "¡Ahora tienes una tarea! Inicia litd con $ litd, hazlo como el usuario que ejecutará litd."
echo "Sigue el proceso de creación de la billetera usando $ lncli --network=[tured] create."
echo "Usa la contraseña ya generada que se puede encontrar a través de $ cat ~/.lnd/wallet_password"
echo "¡¡¡NO OLVIDES RESPALDAR ADECUADAMENTE TU SEMILLA!!!"
echo "Luego, detén litd y ejecuta el siguiente script... ¡¡¡ya casi terminamos!!!"
