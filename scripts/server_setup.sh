#!/bin/bash

# Exit on error
set -e

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root."
  exit 1
fi

# Variables
NEW_USER="ubuntu"
SSH_DIR="/home/$NEW_USER/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"

# 1. Add a new user
if id "$NEW_USER" &>/dev/null; then
  echo "User $NEW_USER already exists."
else
  echo "Creating user $NEW_USER..."
  adduser --gecos "" $NEW_USER
  echo "User $NEW_USER created."
fi

# 2. Grant sudo access if not already configured
if sudo -l -U $NEW_USER 2>/dev/null | grep -q "(ALL)"; then
  echo "User $NEW_USER already has sudo access."
else
  echo "Granting sudo access to $NEW_USER..."
  echo "$NEW_USER ALL=(ALL:ALL) ALL" | tee /etc/sudoers.d/$NEW_USER > /dev/null
  chmod 0440 /etc/sudoers.d/$NEW_USER
  visudo -cf /etc/sudoers.d/$NEW_USER || { echo "ERROR: Invalid sudoers file — removing."; rm /etc/sudoers.d/$NEW_USER; exit 1; }
  echo "Sudo access granted."
fi

# 3. Set up SSH authorized keys
if [ ! -d "$SSH_DIR" ]; then
  echo "Setting up .ssh directory for $NEW_USER..."
  mkdir -p $SSH_DIR
  chmod 700 $SSH_DIR
  chown -R $NEW_USER:$NEW_USER $SSH_DIR
else
  echo ".ssh directory for $NEW_USER already exists."
fi

if [ ! -f "$AUTHORIZED_KEYS" ]; then
  echo "Creating authorized_keys file for $NEW_USER..."
  touch $AUTHORIZED_KEYS
  chmod 600 $AUTHORIZED_KEYS
  chown $NEW_USER:$NEW_USER $AUTHORIZED_KEYS
else
  echo "authorized_keys file for $NEW_USER already exists. Checking for duplicate keys."
fi

# Prompt for SSH keys
echo "Please paste the SSH public keys you want to add. Each key should be on a new line."
echo "When you are finished, press Enter, then Ctrl+D to save and continue."
USER_KEYS=$(cat)

# Add keys provided by the user
while IFS= read -r KEY; do
  if ! grep -qxF "$KEY" $AUTHORIZED_KEYS; then
    echo "$KEY" >> $AUTHORIZED_KEYS
    echo "Added key to authorized_keys."
  else
    echo "Key already exists in authorized_keys. Skipping."
  fi
done <<< "$USER_KEYS"

echo "SSH keys verified for $NEW_USER."

# 4. Disable root login and password authentication
SSHD_CONFIG="/etc/ssh/sshd_config"

if grep -q "^PermitRootLogin yes" $SSHD_CONFIG; then
  echo "Disabling root login..."
  sed -i "s/^#\?PermitRootLogin.*/PermitRootLogin no/" $SSHD_CONFIG
else
  echo "Root login is already disabled."
fi

if grep -q "^#PasswordAuthentication yes" $SSHD_CONFIG || grep -q "^PasswordAuthentication yes" $SSHD_CONFIG; then
  echo "Disabling password authentication..."
  sed -i "s/^#PasswordAuthentication.*/PasswordAuthentication no/" $SSHD_CONFIG
  sed -i "s/^PasswordAuthentication.*/PasswordAuthentication no/" $SSHD_CONFIG
else
  echo "Password authentication is already disabled."
fi

# Restart SSH service
if systemctl is-active --quiet ssh; then
  echo "Warning: Restarting the SSH service may disconnect active sessions. Proceeding..."
  systemctl restart ssh
else
  echo "SSH service is not active. Starting it..."
  systemctl start ssh
fi

echo "Setup completed successfully."

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

Your server is ready for the next script!
EOF