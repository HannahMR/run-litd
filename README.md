# Run Litd

Helper scripts for setting up and running a Lightning node using [Lightning Terminal (litd)](https://github.com/lightninglabs/lightning-terminal).

> These scripts are designed to help developers get set up quickly for testing and application development. Please do appropriate testing before using in production.

Source: [github.com/HannahMR/run-litd](https://github.com/HannahMR/run-litd)  
Demo video: [youtu.be/lopHP_nF0tE](https://youtu.be/lopHP_nF0tE)

Current target versions: **bitcoind v31.0** · **litd v0.16.1-alpha** · **LND v0.20.1-beta**

---

## Which setup is right for you?

| | Quick Start | Routing Node | Remote Signer |
|---|---|---|---|
| **Who it's for** | Get up and running fast | Production routing node | Security-focused / app builders |
| **Bitcoin backend** | Neutrino (lightweight SPV) | bitcoind (full node) | bitcoind or Neutrino |
| **Disk required** | ~1 GB | 80 GB+ pruned / 800 GB+ full | Same as above |
| **Sync time** | Minutes | Hours–days | Same as above |
| **Mainnet routing** | Not recommended | ✓ | ✓ |
| **Signet / dev** | ✓ Ideal | ✓ | ✓ |
| **Scripts** | [`scripts/neutrino/`](scripts/neutrino/) | [`scripts/`](scripts/) | [`scripts/remote-signer/`](scripts/remote-signer/) + [`scripts/neutrino/`](scripts/neutrino/) |

---

## Server Requirements

Tested on Ubuntu 24.04 LTS (also works on 22.04).

| Setup | CPU | RAM | Storage |
|---|---|---|---|
| Quick Start (Neutrino) | 2+ cores | 4 GB+ | ~10 GB |
| Routing Node (bitcoind) | 2+ cores | 4 GB+ | 80 GB+ pruned / 800 GB+ full |
| Remote Signer | 2+ cores per machine | 4 GB+ | Same as above |

For full mainnet nodes on an attached disk, set `datadir=/path/to/disk` in `bitcoin.conf`.

---

## Quick Start (Neutrino)

**Best for:** signet testing, development, getting up and running fast.  
**Not recommended for:** mainnet production routing nodes (peer dependency, reliability limitations).

Neutrino is a lightweight Bitcoin client built into LND — no bitcoind required. Your node syncs from peers in minutes rather than days.

Scripts are in [`scripts/neutrino/`](scripts/neutrino/).

### Single node (litd + Neutrino)

```bash
chmod +x scripts/neutrino/neutrino_setup_binary.sh scripts/neutrino/neutrino_setup3.sh

# Step 1 — install litd and configure Neutrino backend
sudo ./scripts/neutrino/neutrino_setup_binary.sh

# Step 2 — create the LND wallet (run as non-root user)
litd   # start litd in one terminal
lncli --network=signet create   # create wallet in another terminal
# Back up your seed phrase!
# Stop litd (Ctrl-C)

# Step 3 — enable auto-unlock and systemd service
sudo ./scripts/neutrino/neutrino_setup3.sh
```

### Remote signer with Neutrino signer node

For the split architecture but without bitcoind on the signer machine.  
The routing node still uses bitcoind for reliability.

```bash
# On the signer machine
chmod +x scripts/neutrino/remote-signer-neutrino-binary.sh
sudo ./scripts/neutrino/remote-signer-neutrino-binary.sh

# Copy three files to the routing node, then follow the Routing Node steps below
```

---

## Routing Node Setup (bitcoind + litd)

**Best for:** production mainnet routing nodes, reliable long-running nodes.

Scripts are in [`scripts/`](scripts/).

### Step 1 — Bitcoin Core

Two options: build from source or download a binary. Both are idempotent — safe to re-run if interrupted.

```bash
chmod +x scripts/bitcoind_setup.sh scripts/bitcoind_setup_binary.sh

# Binary install (recommended — faster)
sudo ./scripts/bitcoind_setup.sh

# Source build
sudo ./scripts/bitcoind_setup_binary.sh
```

### Step 2 — litd

**Binary install (recommended):**
```bash
chmod +x scripts/litd_setup_binary.sh scripts/litd_setup3.sh
sudo ./scripts/litd_setup_binary.sh

# Create the LND wallet (run as non-root user)
litd   # start litd in one terminal
lncli --network=<mainnet|signet> create   # create wallet in another
# Back up your seed phrase!
# Stop litd (Ctrl-C)

sudo ./scripts/litd_setup3.sh
```

**Source build:**
```bash
chmod +x scripts/litd_setup.sh scripts/litd_setup2.sh scripts/litd_setup3.sh
sudo ./scripts/litd_setup.sh      # installs Go, Node, Yarn
# exit and start a new shell session
sudo ./scripts/litd_setup2.sh     # clones and builds litd
# create wallet as above
sudo ./scripts/litd_setup3.sh     # enables auto-unlock + systemd
```

---

## Remote Signer Setup

The remote signer architecture splits key-holding and routing across two machines:

| Role | Holds keys? | Internet-exposed? |
|---|---|---|
| **Signer node** | Yes — wallet + private keys | No — ideally on a private network |
| **Routing node** | No — watch-only wallet | Yes — public Lightning node |

When litd needs a signature, it calls the signer over an authenticated gRPC connection. Private keys never touch the internet-exposed machine.

Three files are generated on the signer and transferred to the routing node:
- `tls.cert` → rename to `signer-tls.cert` on the routing node
- `signer.macaroon` — minimum-permission signing macaroon
- `accounts.json` — xpubs used to initialise the watch-only wallet

Scripts are in [`scripts/remote-signer/`](scripts/remote-signer/).

### Step 1 — Signer node

Both machines need bitcoind. Run `bitcoind_setup_binary.sh` on each first.

```bash
chmod +x scripts/remote-signer/remote-signer-binary.sh
sudo ./scripts/remote-signer/remote-signer-binary.sh
```

Alternatively, use the Neutrino-based signer (no bitcoind needed on the signer machine):
```bash
chmod +x scripts/neutrino/remote-signer-neutrino-binary.sh
sudo ./scripts/neutrino/remote-signer-neutrino-binary.sh
```

### Step 2 — Transfer files to routing node

```bash
scp ubuntu@<signer-ip>:~/.lnd/tls.cert        ~/.lnd/signer-tls.cert
scp ubuntu@<signer-ip>:~/.lnd/signer.macaroon ~/.lnd/signer.macaroon
scp ubuntu@<signer-ip>:~/.lnd/accounts.json   ~/.lnd/accounts.json
```

### Step 3 — Routing node

All three signer files must be in `~/.lnd/` before running.

**Binary install:**
```bash
chmod +x scripts/remote-signer/routing-node-binary.sh scripts/remote-signer/routing-node3.sh
sudo ./scripts/remote-signer/routing-node-binary.sh

# Create the watch-only wallet (run as non-root user)
litd   # start litd in one terminal
lncli --network=<mainnet|signet> createwatchonly ~/.lnd/accounts.json
# Stop litd (Ctrl-C)

sudo ./scripts/remote-signer/routing-node3.sh
```

**Source build:**
```bash
chmod +x scripts/remote-signer/routing-node.sh scripts/remote-signer/routing-node2.sh scripts/remote-signer/routing-node3.sh
sudo ./scripts/remote-signer/routing-node.sh    # installs Go, Node, Yarn
# exit and start a new shell session
sudo ./scripts/remote-signer/routing-node2.sh   # builds litd
# create watch-only wallet as above
sudo ./scripts/remote-signer/routing-node3.sh   # enables auto-unlock + systemd
```

---

## Server Prep

If starting from a fresh VPS as root, [`scripts/server_setup.sh`](scripts/server_setup.sh) creates an `ubuntu` user with sudo access, adds SSH keys, and hardens SSH. All further scripts should be run as the `ubuntu` user with `sudo`.

---

## Further Reading

- [RUN LND](https://github.com/alexbosworth/run-lnd/) — detailed Lightning node configuration reference
- [Lightning Terminal docs](https://docs.lightning.engineering/lightning-network-tools/lightning-terminal)
- [LND docs](https://docs.lightning.engineering/lightning-network-tools/lnd)
