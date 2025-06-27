# Run Litd

Notes and helper scripts for setting up and running a Litd node.

Important!: These examples and scripts are designed to help developers get set up quickly to begin testing and application development. Please do not trust these files on your production build.  

You can view a demo video of these scripts [here](https://youtu.be/lopHP_nF0tE)

## Contents

1. [Instructions](https://github.com/HannahMR/run-litd/#instructions)
2. [Server Requirements](https://github.com/HannahMR/run-litd/#server-requirements)
3. [Server Prep](https://github.com/HannahMR/run-litd/#server-prep) 
4. [Bitcoind Setup](https://github.com/HannahMR/run-litd/#bitcoind-setup)
5. [Litd Setup](https://github.com/HannahMR/run-litd/#litd-setup)



## Instructions

This guide contains checklists, example files, and helper scripts for getting a Litd node up and running on a ubuntu server. These scripts have been tested on Ubuntu 24.04. There are three major sections to the guide, server prep, bitcoind setup, and litd setup. In each of these sections you will find a description of what needs to happen, a check list to follow, links to example files, and, if you prefer, bash scripts that will run through the checklists for you! 

This repo takes inspiration from the [RUN LND](https://github.com/alexbosworth/run-lnd/) repo. There you can find more detailed information on configuring a Lightning node. 

The current verions of these checklists and scripts installs...

- bitcoind v29.0
- litd v0.15.0-alpha

## Server Requirements

This setup is well tested on Ubuntu servers with at least the below level of resources:

- 2+ CPU Cores
- 80GB+ Storage
- 4GB+ RAM

You will need to increase these resources when running a production server or when running a full node. 

When running a full node on mainnet the server should have at least 800GB. It is common to use an attached disk for the full Blockchain. When doing that you'll need to mount the disk and then add a line to your bitcoin.conf file. 

```datadir=/path/to/the/storage/directory```

When running a pruned node the below line should be uncommented in the bitcoin.conf file. 

```prune=50000 # Prune to 50GB``` 


## Server Prep

This step prepares the server. A new ubuntu user with sudo access is created. SSH keys are added. security is tightened by disabling root login and password authentication. After you run it you'll need to log into the server as the Ubuntu user via SSH. 

This step can be done by following along with the checklist file found at [/checklists/server-setup-checklist.txt](https://github.com/HannahMR/run-litd/blob/main/checklists/server-setup-checklist.txt) or by running the setup bash script at [/scripts/server_setup.sh](https://github.com/HannahMR/run-litd/blob/main/scripts/server_setup.sh) 

### Server Prep Helper Script

You will be propted to paste in your team's ssh keys as the script runs.   

Don't forget to make executable before trying to run it. 

```$ chmod +x server_setup.sh``` 

The script should be run with sudo. Don't worry, repo's, files, etc. will be owned by your current user(a new user called ubuntu if the server_setup script was used).

```$ sudo ./server_setup.sh```

You'll like want to move the run-litd repo to the new ubuntu users home directory. 

```$ sudo mv /root/run-litd/ /home/ubuntu/run-litd/```
```$ sudo mv chown -R ubuntu:ubuntu /home/ubuntu/run-litd/```

## Bitcoind Setup

This step installs and runs bitcoind. The server is brought up to date, bitcoind dependancies are installed, bitcoind is built or the binary downloaded, a config file is created, a systemd .service file is created and bitcoind is run. There are two scripts and checklists here. One for building from source, and one for downloading a binary. 

As the scripts run you will be prompted to select signet or mainnet. 

This step can be done by following along with the checklist file found here [/checklists/bitcoind-setup-checklist.txt](https://github.com/HannahMR/run-litd/blob/main/checklists/bitcoind-setup-checklist.txt) and here [/checklists/bitcoind-setup-binary-checklist.txt](https://github.com/HannahMR/run-litd/blob/main/checklists/bitcoind-setup-binary-checklist.txt) or by running one of the setup bash scripts here [/scripts/bitcoind_setup.sh](https://github.com/HannahMR/run-litd/blob/main/scripts/bitcoind_setup.sh) or here [/scripts/bitcoind_setup_binary.sh](https://github.com/HannahMR/run-litd/blob/main/scripts/bitcoind_setup_binary.sh) 

### Bitcoind Setup Helper Script

Please double check the default values included in the config file in the scripts before running one of the scripts. Values such as network, passwords, etc will be selected/generated when the scripts run. 

There are two scripts to chose from here, one which installs from source, bitcoind_setup.sh, and one which installs a binary, bitcoind_setup_binary.sh. Which ever script you chose you will want to run it as the new users that was created in the server setup process.

These scripts default to running a pruned node set to 50GB. If you would like to run a full node or store the blockchain data on an attached disk, you will need to edit the script accordingly. 

They also run checks to see what's been done as they go, and so should be safe to run multiple times in case any run has been interupted. 

If you originally cloned this repo to /root you may want to move it to /home/ubuntu and change the owner for easier running. 

Don't forget to make the scripts executable before trying to run them. 

```$ chmod +x bitcoind_setup.sh``` 
```$ chmod +x bitcoind_setup_binary.sh``` 

The script should be run with sudo. Don't worry, repo's, files, etc. will be owned by your current user, a new user called ubuntu if the server_setup script was used).

```$ sudo ./bitcoind_setup.sh```
```$ sudo ./bitcoind_setup_binary.sh``` 



## Litd Setup

This step installs and runs litd. When installing from source GoLang and NodeJS are installed, the repo is cloned and litd is built. When installing from binary the appropriate files are downloaded, a lit.conf file is generated, an LND wallet is created, the password saved, and the config set to auto unlock at startup, a systemd .service file is created, and litd is started!

Litd installation is helped with this repo in a number of ways. You can follow along with the setup  checklist files, the install from source checklist is here [/checklists/litd-setup-checklist.txt](https://github.com/HannahMR/run-litd/blob/main/checklists/litd-setup-checklist.txt) and the install from binary checklist is here [/checklists/litd-setup-binary-checklist.txt](https://github.com/HannahMR/run-litd/blob/main/checklists/litd-setup-binary-checklist.txt)

Bash scripts can also be used to install either from source or from binary. To install from source run the setup bash scripts at [/scripts/litd_setup.sh](https://github.com/HannahMR/run-litd/blob/main/scripts/litd_setup.sh), [/scripts/litd_setup2.sh](https://github.com/HannahMR/run-litd/blob/main/scripts/litd_setup2.sh) and [/scripts/litd_setup3.sh](https://github.com/HannahMR/run-litd/blob/main/scripts/litd_setup3.sh)

To install a binary run the setup bash scripts at [/scripts/litd_setup_binary.sh](https://github.com/HannahMR/run-litd/blob/main/scripts/litd_setup_binary.sh) and [/scripts/litd_setup3.sh](https://github.com/HannahMR/run-litd/blob/main/scripts/litd_setup3.sh)

### Litd Setup Helper Script

These scripts run checks to see what's been done as they go, and so should be safe to run multiple times in case any run has been interupted. 

If you are installing from source there are three scripts to be run here, litd_setup.sh, litd_setup2.sh and then litd_setup3.sh. You'll need to run the first script and then end the current bash session and start a new one before running the second. You will need to walk through the wallet creation process after running script two and before script three.

If you are installing the binary there are two script to be run here, litd_setup_binary.sh and litd_setup3.sh. After running the litd_setup_binary.sh script you will need to walk through the wallet creation process before running litd_setup3.sh.

Don't forget to make them executable before trying to run them.

```$ chmod +x litd_setup*```

The scripts should be run with sudo. Don't worry, repo's, files, etc. will be owned by your current user, a new user called ubuntu if the server_setup script was used).

```$ sudo ./litd_setup.sh```
```$ sudo ./litd_setup_binary.sh```
```$ sudo ./litd_setup2.sh``` 
```$ sudo ./litd_setup3.sh```

Happy Building! 


