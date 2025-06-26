#!/bin/bash

# Salir en caso de error
set -e

# Verificar privilegios de root
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecute como root."
  exit 1
fi

# Variables
NEW_USER="ubuntu"
SSH_DIR="/home/$NEW_USER/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

# 1. Agregar un nuevo usuario
if id "$NEW_USER" &>/dev/null; then
  echo "El usuario $NEW_USER ya existe."
else
  echo "Creando usuario $NEW_USER..."
  adduser --gecos "" $NEW_USER
  adduser --gecos "" $NEW_USER && passwd $NEW_USER
  echo "$NEW_USER ALL=(ALL:ALL) ALL" >> /etc/sudoers
  echo "Usuario $NEW_USER agregado y se le otorgó acceso sudo."
fi

# 2. Configurar las claves autorizadas de SSH
if [ ! -d "$SSH_DIR" ]; then
  echo "Configurando el directorio .ssh para $NEW_USER..."
  mkdir -p $SSH_DIR
  chmod 700 $SSH_DIR
  chown -R $NEW_USER:$NEW_USER $SSH_DIR
else
  echo "El directorio .ssh para $NEW_USER ya existe."
fi

if [ ! -f "$AUTHORIZED_KEYS" ]; then
  echo "Creando el archivo authorized_keys para $NEW_USER..."
  touch $AUTHORIZED_KEYS
  chmod 600 $AUTHORIZED_KEYS
  chown $NEW_USER:$NEW_USER $AUTHORIZED_KEYS
else
  echo "El archivo authorized_keys para $NEW_USER ya existe. Verificando claves duplicadas."
fi

# Solicitar claves SSH
echo "Por favor, pegue las claves públicas SSH que desea agregar. Cada clave debe estar en una nueva línea."
echo "Cuando haya terminado, presione Enter, luego Ctrl+D para guardar y continuar."
USER_KEYS=$(cat)

# Agregar claves proporcionadas por el usuario
while IFS= read -r KEY; do
  if ! grep -qxF "$KEY" $AUTHORIZED_KEYS; then
    echo "$KEY" >> $AUTHORIZED_KEYS
    echo "Clave agregada a authorized_keys."
  else
    echo "La clave ya existe en authorized_keys. Omitiendo."
  fi
done <<< "$USER_KEYS"

echo "Claves SSH verificadas para $NEW_USER."

# 3. Deshabilitar el inicio de sesión de root y la autenticación por contraseña
SSHD_CONFIG="/etc/ssh/sshd_config"

if grep -q "^PermitRootLogin yes" $SSHD_CONFIG; then
  echo "Deshabilitando el inicio de sesión de root..."
  sed -i "s/^#\?PermitRootLogin.*/PermitRootLogin no/" $SSHD_CONFIG
else
  echo "El inicio de sesión de root ya está deshabilitado."
fi

if grep -q "^#PasswordAuthentication yes" $SSHD_CONFIG || grep -q "^PasswordAuthentication yes" $SSHD_CONFIG; then
  echo "Deshabilitando la autenticación por contraseña..."
  sed -i "s/^#PasswordAuthentication.*/PasswordAuthentication no/" $SSHD_CONFIG
  sed -i "s/^PasswordAuthentication.*/PasswordAuthentication no/" $SSHD_CONFIG
else
  echo "La autenticación por contraseña ya está deshabilitada."
fi

# Reiniciar el servicio SSH
if systemctl is-active --quiet ssh; then
  echo "Advertencia: Reiniciar el servicio SSH puede desconectar las sesiones activas. Procediendo..."
  systemctl restart ssh
else
  echo "El servicio SSH no está activo. Iniciándolo..."
  systemctl start ssh
fi

echo "Configuración completada con éxito."

cat <<"EOF"


             .------~---------~-----.
             | .------------------. |
             | |                  | |
             | |   .'''.  .'''.   | |
             | |   :    ''    :   | |
             | |   :          :   | |
             | |    '.      .'    | |
             | |      '.  .'      | |
             | |        ''        | |  
             | `------------------' |  
             `.____________________.'  
               `-------.  .-------'    
        .--.      ____.'  `.____       
      .-~--~-----~--------------~----. 
      |     .---------.|.--------.|()| 
      |     `---------'|`-o-=----'|  | 
      |-*-*------------| *--  (==)|  | 
      |                |          |  | 
      `------------------------------' 

Tu servidor está listo para el próximo script!
EOF
