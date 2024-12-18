# Run Litd

Notes and helper scripts for setting up and running a Litd node.

## Contents

1. [Instructions](https://github.com/HannahMR/run-litd/#instructions)
2. [Server Requirements](https://github.com/HannahMR/run-litd/#server-requirements)
3. [Server Prep](https://github.com/HannahMR/run-litd/#server-prep) 
4. [Bitcoind Setup](https://github.com/HannahMR/run-litd/#bitcoind-setup)
5. [Litd Setup](https://github.com/HannahMR/run-litd/#litd-setup)



## Instructions

This guide contains checklists, example files, and helper scripts for getting a Litd node up and running on a ubuntu server. There are three major sections to the guide, server prep, bitcoind setup, and litd setup. In each of these sections you will find a description of what needs to happen, a check list to follow, links to example files, and, if you prefer, bash scripts that will run through the checklists for you! 

The current verions of these checklists and scripts installs...

- bitcoind v27.2
- litd v0.13.6-alpha

## Server Requirements

This setup is well tested on Ubuntu servers with at least the below level of resources:

- 2+ CPU Cores
- 80GB+ Storage
- 4GB+ RAM

You will need to increase these resources when running a production server or when running a full node. 

When running a full node on mainnet the server should have at least 800GB. It is common to use an attached disk for the full Blockchain. When doing that you'll need to mount the disk and then add a line to your bitcoin.conf file. 

```datadir=/path/to/the/storage/directory```

When running a pruned node the below line should be uncommented in the bitcoin.conf file. 

```prune=80000 # Prune to 80GB``` 


## Server Prep

This step prepares the server. A new ubuntu user with sudo access is created. SSH keys are added. security is tightened by disabling root login and password login.

This step can be done by following along with the checklist file found at /checklists/server-setup-checklist.txt or by running the setup bash script at /scripts/server_setup.sh 

### Server Prep Helper Script

You will need to add your team's keys ssh pubkeys to the script on line 17. 

Don't forget to make executable before trying to run it. 

```$ chmod +x server_setup.sh``` 

The script should be run with sudo. Don't worry, repo's, files, etc. will be owned by your current user(a new user called ubuntu if the server_setup script was used).

```$ sudo ./server_setup.sh```



## Bitcoind Setup

This step installs and runs bitcoind. The server is brought up to date, bitcoind dependancies are installed, the repo is cloned and bitcoind is built, a config file is created, a systemd .service file is created and bitcoind is run. 

This step can be done by following along with the checklist file found at /checklists/bitcoind-setup-checklist.txt or by running the setup bash script at /scripts/bitcoind_setup.sh 

### Bitcoind Setup Helper Script

Please double check the default values included in the config file in the script, lines 107-160, before running the script. Values such as network, passwords, etc will be selected/generated when the scritp runs. 

Don't forget to make executable before trying to run it. 

```$ chmod +x bitcoind_setup.sh``` 

The script should be run with sudo. Don't worry, repo's, files, etc. will be owned by your current user(a new user called ubuntu if the server_setup script was used).

```$ sudo ./bitcoind_setup.sh```



## Litd Setup


### Bitcoind Setup Helper Script

Don't forget to make executable before trying to run it. 

```$ chmod +x litd_setup.sh``` 

The script should be run with sudo. Don't worry, repo's, files, etc. will be owned by your current user(a new user called ubuntu if the server_setup script was used).

```$ sudo ./litd_setup.sh```












