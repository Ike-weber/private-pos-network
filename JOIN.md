# Joining the Private PoS Devnet

This guide is for participants who want to run a node in Harsh's private Ethereum Proof-of-Stake devnet. It is written for non-experts and works on Windows (WSL), Mac, and Linux.

## What this network is

A private, invite-only Ethereum PoS network running on Chain ID `12345`.
- There are **9 validators** total, split across participants.
- The network uses **real Geth + Prysm** clients, not a simulator.
- The network uses **Electra** fork rules from genesis.
- Each participant runs one node: one Geth execution client, one Prysm beacon node, and one Prysm validator.
- A **Mac Mini is the permanent bootnode** (seed node). Your node connects to it to discover peers.
- All ETH is fake devnet ETH. Do not send real funds.

## What you need

- A computer running **Windows 10/11 with WSL**, **macOS 12+**, or **Linux**.
- At least **4 CPU cores and 8 GB RAM**.
- **~50 GB free disk space**.
- An internet connection to download Geth and Prysm.
- An invitation from the network owner with:
  - Your assigned **node number** (1-9).
  - The **bootnode IP** (Mac Mini).
  - A **keystore directory** for your validator.
  - The shared **JWT secret** file.

## Quick checklist

1. Install dependencies (git, curl, jq).
2. Clone the repo.
3. Install Geth and Prysm.
4. Copy your keystore and JWT secret into the repo.
5. Fill in `node-config.env`.
6. Run `./join-network.sh`.
7. Check logs and health.

---

## 1. Install dependencies

### Windows (WSL)

Open PowerShell and run:

```powershell
wsl --install
```

Then open **Ubuntu (WSL)** from the Start menu.

Inside WSL, run:

```bash
sudo apt update
sudo apt install -y git curl jq
```

### Mac

Open **Terminal** from Applications > Utilities.

Install Homebrew if you don't have it:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Then install dependencies:

```bash
brew install git curl jq
```

### Linux

Open a terminal and run:

```bash
# Debian / Ubuntu
sudo apt update
sudo apt install -y git curl jq

# Fedora / RHEL
sudo dnf install -y git curl jq

# Arch
sudo pacman -S git curl jq
```

---

## 2. Clone the repository

```bash
git clone https://github.com/harsh/private-pos.git
cd private-pos
```

Or use the exact repo URL the network owner gave you.

---

## 3. Install Geth and Prysm

The repository has a helper script that downloads the correct versions for you.

### Option A: Use the automatic download script (recommended)

```bash
./download-binaries.sh
```

This will create:
- `geth-1.17.4`
- `beacon-chain-v7.1.6`
- `validator-v7.1.6`
- `prysmctl-v7.1.6`

### Option B: Manual download

If the script fails, download these files manually and place them in the repo folder:

- Geth: https://gethstore.blob.core.windows.net/builds/geth-linux-amd64-1.17.4-36a7dc72.tar.gz
- Prysm: https://github.com/OffchainLabs/prysm/releases/download/v7.1.6/beacon-chain-v7.1.6-linux-amd64
- Prysm validator: https://github.com/OffchainLabs/prysm/releases/download/v7.1.6/validator-v7.1.6-linux-amd64

Make them executable:

```bash
chmod +x geth-1.17.4 beacon-chain-v7.1.6 validator-v7.1.6
```

---

## 4. Copy your keystore and JWT secret

The network owner will give you:
- A folder named `keystore-nodeX` (where X is your node number), containing your validator keys.
- A file named `jwt-secret` (the shared JWT secret for the Engine API).

Copy them into the repo folder:

```bash
# Replace X with your node number
cp -r /path/to/keystore-nodeX ./keystore

cp /path/to/jwt-secret ./jwt-secret
```

**Never share these files with anyone.** They are your validator credentials and network access token.

---

## 5. Configure your node

Copy the example config file:

```bash
cp node-config.example.env node-config.env
```

Open `node-config.env` in a text editor and fill in the values:

```bash
nano node-config.env
```

Example values:

```env
# Your node number (1-9). Node 1 is the bootnode (Mac Mini).
NODE_ID=3

# Your machine's IP on the local network. Use 127.0.0.1 only if you are testing on one machine.
MACHINE_IP=192.168.1.100

# The bootnode IP (Mac Mini). The network owner will give you this.
BOOTNODE_IP=192.168.1.50

# The bootnode's P2P TCP port. Usually 13000.
BOOTNODE_P2P_PORT=13000

# The bootnode's peer ID. The network owner will give you this.
BOOTNODE_PEER_ID=16Uiu2HAm...replace.me...

# Path to your validator keystore folder (inside the repo).
KEYSTORE_DIR=./keystore

# Path to the shared JWT secret.
JWT_SECRET_PATH=./jwt-secret

# Suggested fee recipient (your wallet address, or use the default).
FEE_RECIPIENT=0xDeaDbeefdEAdbeefdEadbEEFdeadbeefDeAdbeEf
```

To find your machine's IP:

```bash
# Windows / Linux
hostname -I

# Mac
ipconfig getifaddr en0
```

---

## 6. Run the join script

One command starts your node:

```bash
./join-network.sh
```

This script will:
1. Detect your operating system.
2. Initialize your Geth datadir with the shared `genesis.json`.
3. Import your validator keystore into Prysm.
4. Start Geth, the Prysm beacon node, and the Prysm validator.
5. Connect your beacon node to the bootnode (Mac Mini).

You should see output like:

```
OS: Linux
Initializing Geth...
Geth initialized
Importing validator keystore...
Keystore imported
Starting Geth...
Geth ready
Starting beacon node...
Beacon node ready
Starting validator...
Validator started
Node 3 is running. Press Ctrl+C to stop.
```

---

## 7. Check that your node is healthy

Open a new terminal (keep the first one running) and run:

### Check Geth sync

```bash
curl -s http://localhost:8543 -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | jq
```

You should see a hex number that increases over time.

### Check beacon node identity

```bash
curl -s http://localhost:3502/eth/v1/node/identity | jq
```

You should see your `peer_id` and a list of peers including the bootnode.

### Check validators

```bash
curl -s http://localhost:3502/eth/v1/beacon/states/head/validators | jq '.data | length'
```

This should show 9 validators once everyone is online.

### Check your validator is submitting attestations

```bash
tail -f logs/validator.log
```

Look for lines like `Submitted new attestations`.

---

## 8. Stopping your node

Press **Ctrl+C** in the terminal where `join-network.sh` is running.

If you ran it in the background, use:

```bash
./stop-all.sh
```

---

## 9. Troubleshooting

### `join-network.sh` says OS is not supported

Make sure you are running it inside WSL (Windows), macOS Terminal, or a Linux shell. Native Windows CMD/PowerShell is not supported for the script.

### Geth fails to start

- Check that `genesis.json` is in the repo folder.
- Check that your Geth binary is executable: `chmod +x geth-1.17.4`.
- Check `logs/geth.log` for errors.

### Beacon node cannot connect to bootnode

- Make sure `BOOTNODE_IP`, `BOOTNODE_P2P_PORT`, and `BOOTNODE_PEER_ID` are correct.
- Check that your machine can reach the bootnode IP on the network.
- Check `logs/beacon.log` for peer connection errors.

### Validator not working

- Check that your keystore folder exists and is readable.
- Check `logs/validator-import.log` for import errors.
- Check `logs/validator.log` for errors.

### Port already in use

If you have another node running, the ports may conflict. Make sure `NODE_ID` is unique and no other Ethereum client is running.

### Windows/WSL networking issues

WSL uses a virtual network. If other machines cannot reach your WSL node, try setting `MACHINE_IP` to your Windows host IP and forwarding the required ports, or use a VPN/ZeroTier.

---

## 10. Security reminders

- **Never commit your keystore or JWT secret.** They are ignored by `.gitignore`, but double-check.
- **Do not expose Geth HTTP (port 854x) or the beacon REST API (port 350x) to the internet.** Only open these on your local network or VPN.
- **All ETH is fake.** Do not send real ETH to the deposit contract.
- **Keep your mnemonic safe** if you generated one. The network owner may have it, but you should not share it.

---

## 11. Getting help

If you get stuck, run the diagnostic command and share the output:

```bash
./diagnose.sh
```

If that file doesn't exist, share the following:

```bash
uname -a
ls -la
ls logs/
tail -n 50 logs/geth.log
tail -n 50 logs/beacon.log
tail -n 50 logs/validator.log
```
