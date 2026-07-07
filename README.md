# Private Ethereum PoS Devnet

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Fork: Electra](https://img.shields.io/badge/Fork-Electra-blue)](https://github.com/ethereum/consensus-specs)
[![Chain ID: 12345](https://img.shields.io/badge/Chain%20ID-12345-green)](https://chainlist.org/chain/12345)
[![Block Time: 12s](https://img.shields.io/badge/Block%20Time-12s-orange)](https://ethereum.org/en/roadmap/merge/)

A fully functional, local-only Ethereum Proof-of-Stake (PoS) devnet with up to 3 Geth execution nodes, 3 Prysm beacon nodes, and 3 genesis validators — plus a real deposit contract that lets anyone with 32 devnet ETH become a validator. Designed for smart contract development, protocol testing, and consensus-layer experimentation without public testnet dependencies.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Network Specs](#network-specs)
- [Prerequisites](#prerequisites)
- [Directory Structure](#directory-structure)
- [Configuration Reference](#configuration-reference)
- [Quick Start](#quick-start)
- [How PoS Works Here](#how-pos-works-here)
- [Real Validator Deposits](#real-validator-deposits-permissionless-staking)
- [Network Ports](#network-ports)
- [Interacting with the Network](#interacting-with-the-network)
- [Connecting MetaMask](#connecting-metamask)
- [Funding Accounts](#funding-accounts)
- [Deploying Smart Contracts](#deploying-smart-contracts)
- [Monitoring Node Health](#monitoring-node-health)
- [Performance Requirements](#performance-requirements)
- [Security Warnings](#security-warnings)
- [Troubleshooting](#troubleshooting)
- [Full Reset Procedure](#full-reset-procedure)
- [Extending the Network](#extending-the-network)
- [Known Limitations](#known-limitations)
| [Single-Node Mode](#single-node-mode)
| [Joining the Network](#joining-the-network)
| [Changelog](#changelog)
| [License](#license)
| [Contributors](#contributors)

---

## Overview

This devnet is a self-contained Ethereum network that runs entirely on your local machine. Unlike mainnet or public testnets (Goerli, Sepolia, Holesky), this network:

- **Requires no external peers** — all nodes are local
- **Has fast finality** — 3 genesis validators control the network; more can join via real deposits
- **Costs nothing** — all ETH is fake/devnet-only
- **Resets instantly** — wipe data and restart in under 2 minutes
- **Uses the Electra fork** — Altair, Bellatrix, Capella, Deneb and Electra are active from genesis
- **Supports real deposits** — anyone with 32 devnet ETH can call the deposit contract and activate a new validator

**Primary Use Cases:**
- Smart contract development and testing
- Consensus layer research and experimentation
- Validator client testing
- Engine API / execution layer integration testing
- Educational purposes for understanding Ethereum PoS

| **What Makes It Different:**
|- Uses **interop validators** (pre-generated deterministic keys, not real deposits) for the genesis set
|- Active forks from **epoch 0** (no waiting for upgrades)
|- **Real deposit contract** at `0x4242424242424242424242424242424242424242` — anyone with 32 devnet ETH can deposit and become a validator
|- **Local-only** — not discoverable on the public internet

---

## Architecture

```
+-------------------------------------------------------------------------+
|                           PRIVATE POS DEVNET                             |
|                              (Local Machine)                             |
+-------------------------------------------------------------------------+
|                                                                          |
|  +-------------+    +-------------+    +-------------+                   |
|  | Validator 1 |    | Validator 2 |    | Validator 3 |                   |
|  |  (interop)  |    |  (interop)  |    |  (interop)  |                   |
|  |  genesis    |    |  genesis    |    |  genesis    |                   |
|  +------+------+    +------+------+    +------+------+                   |
|         |                  |                  |                          |
|         | REST API         | REST API         | REST API                 |
|         | (port 3500)      | (port 3501)      | (port 3502)              |
|         v                  v                  v                          |
|  +-------------+    +-------------+    +-------------+                   |
|  |  Beacon 1   |<-->|  Beacon 2   |<-->|  Beacon 3   |                   |
|  |   Prysm     |    |   Prysm     |    |   Prysm     |                   |
|  |  (p2p:13000)|    |  (p2p:13001)|    |  (p2p:13002)|                   |
|  +------+------+    +------+------+    +------+------+                   |
|         |                  |                  |                          |
|         | Engine API (JWT) | Engine API (JWT) | Engine API (JWT)         |
|         | (port 8551)      | (port 8552)      | (port 8553)              |
|         v                  v                  v                          |
|  +-------------+    +-------------+    +-------------+                   |
|  |   Geth 1    |<-->|   Geth 2    |<-->|   Geth 3    |                   |
|  |  Execution  |    |  Execution  |    |  Execution  |                   |
|  |  (http:8541)|    |  (http:8542)|    |  (http:8543)|                   |
|  +-------------+    +-------------+    +-------------+                   |
|                                                                          |
|  Data Flow:                                                              |
|  1. Validator proposes block -> Beacon builds consensus block            |
|  2. Beacon calls Engine API (forkchoiceUpdated) -> Geth builds payload   |
|  3. Geth returns payload -> Beacon includes it in block                  |
|  4. Beacon publishes block -> Validators attest to it                    |
|  5. Geth peers sync execution blocks via p2p (ports 30301-30303)         |
|                                                                          |
+-------------------------------------------------------------------------+
```

---

## Network Specs

| Parameter | Value |
|-----------|-------|
| **Chain ID** | `12345` |
| **Network ID** | `12345` |
| **Fork** | Electra (Altair/Bellatrix/Capella/Deneb/Electra active from genesis) |
| **Preset** | Interop (minimal config) |
| **Slots per Epoch** | `6` |
| **Block Time** | `12` seconds |
|| **Validator Count** | `3` genesis validators (more can join via 32 ETH deposit) |
| **Genesis Time** | dynamic on reset (3 minutes from `run-pos.sh` invocation) |
| **Consensus Client** | Prysm v5.3.2 |
| **Execution Client** | Geth v1.17.4 |
| **Genesis Block Hash** | dynamic on reset |

---

## Prerequisites

| Tool | Minimum Version | Purpose | Install Command |
|------|----------------|---------|---------------|
| **curl** | 7.74+ | HTTP requests | `sudo apt install curl` |
| **jq** | 1.6+ | JSON parsing | `sudo apt install jq` |
| **Python3** | 3.10+ | Scripting helpers | `sudo apt install python3` |
| **tar** | any | Extract Geth archive | usually pre-installed |

**Disk:** ~2 GB free space for binaries and chain data.

**Note:** This setup uses pre-built Prysm and Geth binaries. It does **not** build from source.

---

## Directory Structure

```
~/eth-pos/private-pos/
├── beacon1/                  # Beacon node 1 data (Prysm DB, p2p cache)
│   └── validator/            # Validator 1 keys and slashing protection
├── beacon2/                  # Beacon node 2 data
│   └── validator/            # Validator 2 keys
├── beacon3/                  # Beacon node 3 data
│   └── validator/            # Validator 3 keys
├── node1/                    # Geth execution node 1 data
│   └── geth/                 # Chaindata, trie cache, nodekey
├── node2/                    # Geth execution node 2 data
│   └── geth/
├── node3/                    # Geth execution node 3 data
│   └── geth/
├── logs/                     # All process logs
│   ├── beacon1.log           # Beacon node 1 stdout/stderr
│   ├── beacon2.log
│   ├── beacon3.log
│   ├── geth1.log
│   ├── geth2.log
│   ├── geth3.log
│   ├── validator1.log
│   ├── validator2.log
│   ├── validator3.log
│   └── start.log             # start-all.sh output
├── dist/                     # Downloaded Prysm binaries
│   ├── beacon-chain-v5.3.2-linux-amd64
│   ├── validator-v5.3.2-linux-amd64
│   └── prysmctl-v5.3.2-linux-amd64
├── config.yaml               # Consensus chain configuration (fork epochs, presets)
├── genesis.json              # Execution layer genesis (alloc, config, extraData)
├── genesis.json.working      # Execution genesis template used by prysmctl
├── genesis.ssz               # Consensus genesis state (SSZ format, generated by prysmctl)
├── jwt.hex                   # Shared JWT secret for Engine API authentication
├── run-pos.sh                # Full reset script: wipe -> genesis -> start
├── start-all.sh              # Start all 9 processes with correct peering
├── stop-all.sh               # Kill all devnet processes
├── prysm.sh                  # Prysm launcher wrapper (downloads/verifies Prysm)
├── send_deposit_new.py       # Submit a real 32 ETH deposit to become a validator
├── deposit_data_new.json     # Example validator deposit data (BLS keys, signature, root)
├── start-single-node.sh      # Lightweight single-node deployment (1 Geth + 1 beacon + 1 validator)
├── geth-flags.txt            # Reference Geth execution-layer flags
├── geth-1.15.11              # Pre-built Geth binary
├── README.md                 # This file
└── .git/                     # Git repository
```

---

## Configuration Reference

### `config.yaml` — Consensus Chain Config

This file tells Prysm when each consensus upgrade (fork) activates.

```yaml
# -- Network Identity --
PRESET_BASE: interop               # Minimal preset for fast epochs (6 slots/epoch)
CONFIG_NAME: interop               # Human-readable config name

# -- Genesis Parameters --
GENESIS_FORK_VERSION: 0x20000089   # Unique fork version to prevent mainnet replay
GENESIS_DELAY: 0                   # No built-in delay; run-pos.sh schedules genesis 3 min ahead

# -- Fork Schedule (active from genesis) --
ALTAIR_FORK_EPOCH: 0               # Sync committees, light client support
BELLATRIX_FORK_EPOCH: 0            # The Merge — PoS transition
CAPELLA_FORK_EPOCH: 0              # Withdrawals, BLS to execution changes
DENEB_FORK_EPOCH: 0                # Blob transactions (EIP-4844)
ELECTRA_FORK_EPOCH: 0              # Validator consolidation, pending deposits
FULU_FORK_EPOCH: 18446744073709551615  # Disabled (max uint64)

# -- Time Parameters --
SECONDS_PER_SLOT: 12               # Block time (12 seconds = Ethereum standard)
SLOTS_PER_EPOCH: 6                 # 6 slots x 12s = 72 second epochs

# -- Validator Parameters --
MIN_GENESIS_ACTIVE_VALIDATOR_COUNT: 1    # Only 3 interop validators; keep minimum low
MIN_GENESIS_TIME: 0                # No minimum time constraint

# -- Deposit Contract (dummy for interop) --
DEPOSIT_CHAIN_ID: 12345
DEPOSIT_NETWORK_ID: 12345
DEPOSIT_CONTRACT_ADDRESS: 0x4242424242424242424242424242424242424242
```

**Why These Values:**
- `PRESET_BASE: interop`: Minimal preset reduces epoch time to 72 seconds.
- `GENESIS_FORK_VERSION: 0x20000089`: First byte `0x20` distinguishes from mainnet (`0x00`), preventing accidental replay attacks.
- Active forks at epoch 0: Blob transactions, withdrawals, and sync committees are available immediately.
- `FULU_FORK_EPOCH: 18446744073709551615`: Fulu is disabled because the current Geth/Prysm combination does not support Fulu payload building in this interop configuration.

### `genesis.json` — Execution Genesis

```json
{
  "config": {
    "chainId": 12345,
    "homesteadBlock": 0,
    "eip150Block": 0,
    "eip155Block": 0,
    "eip158Block": 0,
    "byzantiumBlock": 0,
    "constantinopleBlock": 0,
    "petersburgBlock": 0,
    "istanbulBlock": 0,
    "berlinBlock": 0,
    "londonBlock": 0,
    "arrowGlacierBlock": 0,
    "grayGlacierBlock": 0,
    "mergeNetsplitBlock": 0,
    "terminalTotalDifficulty": 0,
    "terminalTotalDifficultyPassed": true,
    "shanghaiTime": 0,
    "cancunTime": 0,
    "pragueTime": 0,
    "blobSchedule": {
      "cancun": {"target": 3, "max": 6, "baseFeeUpdateFraction": 3338477},
      "prague": {"target": 6, "max": 9, "baseFeeUpdateFraction": 5007716}
    }
  },
  "alloc": {
    "0x8B0681dBD724dcaC48b433e9df8A220D47C94a19": {"balance": "0x21E19E0C9BAB2400000"},
    "0x6Bd7f3AfB4f2B1E3f8d5C4E9A7B2C1D0E8F6A5B4": {"balance": "0x21E19E0C9BAB2400000"},
    "0xA1B2C3D4E5F6789012345678901234567890ABCD": {"balance": "0x21E19E0C9BAB2400000"}
  },
  "coinbase": "0x0000000000000000000000000000000000000000",
  "difficulty": "0x1",
  "extraData": "0x",
  "gasLimit": "0x1c9c380",
  "nonce": "0x0",
  "mixhash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "parentHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
  "timestamp": "0x<dynamic>"
}
```

**Critical Fields Explained:**
- `terminalTotalDifficultyPassed: true`: **REQUIRED** for Geth v1.14.0+. Tells Geth the Merge already happened.
- `terminalTotalDifficulty: 0`: Sets the PoW -> PoS threshold to 0, so the transition is immediate.
- `blobSchedule`: **REQUIRED** for Cancun and later. Defines blob transaction parameters per fork.
- `shanghaiTime/cancunTime/pragueTime: 0`: Timestamp 0 means these execution upgrades are active from genesis.

### `jwt.hex` — Engine API Authentication

A shared 32-byte hex secret that both Geth and Prysm use to authenticate Engine API requests. Generated once and reused across restarts.

```bash
# Generate a new JWT secret
openssl rand -hex 32 > jwt.hex
```

**Why It Matters:** The Engine API (port 8551) is a privileged interface. Without JWT authentication, anyone with network access could control block production.

---

## Quick Start

### 1. Start the Network

```bash
cd ~/eth-pos/private-pos
./run-pos.sh
```

This script will:
1. Download Geth v1.17.4 automatically (with fallback sources) if missing
2. Download Prysm v5.3.2 binaries (`beacon-chain`, `validator`, `prysmctl`) automatically if missing
3. Generate `jwt.hex` if missing
4. Remove any stale `genesis.ssz`/`genesis.json` from previous runs
5. Generate `genesis.ssz` (consensus genesis with `--fork electra`)
6. Generate `genesis.json` (execution genesis)
7. Apply fixes (`terminalTotalDifficultyPassed`, `blobSchedule`, etc.)
8. Initialize Geth nodes with the genesis block
9. Start all 9 processes with proper peering

**Wait time:** ~3 minutes (genesis is set 3 minutes in the future so all processes start before chain genesis).

### 2. Verify the Chain is Running

```bash
# Check Geth block number (should advance every 12 seconds)
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://localhost:8541 | python3 -c "import sys,json; print('block:', int(json.load(sys.stdin)['result'],16))"

# Check beacon chain head
curl -s http://localhost:3500/eth/v1/beacon/headers/head | jq

# Check validator status
curl -s http://localhost:3500/eth/v1/beacon/states/head/validators | jq '.data | length'
```

### 3. Stop the Network

```bash
./stop-all.sh
```

### 4. Full Reset (Wipe Everything)

```bash
./run-pos.sh
```

This wipes all data directories and regenerates genesis. Use when:
- Fork configuration changes
- Genesis timestamp is in the past
- Database corruption suspected
- Starting fresh after troubleshooting

---

## How PoS Works Here

### The Merge Architecture

Unlike PoW (mining), PoS uses **validators** who stake ETH to propose and attest to blocks. The **beacon chain** coordinates validators, while the **execution layer** (Geth) handles transactions and state.

```
+-----------------+------------------+
|  Beacon Chain   |  Execution Layer  |
|    (Prysm)      |     (Geth)       |
|                 |                  |
|  * Slot timing  |  * Transactions  |
|  * Validator    |  * State trie    |
|    scheduling   |  * EVM execution |
|  * Fork choice  |  * Block building|
|  * Rewards/     |                  |
|    penalties    |                  |
+-----------------+------------------+
         |                  |
         | Engine API (JWT) |
         | (port 8551)      |
         +------------------+
```

### Key Concepts

| Term | Explanation | In This Devnet |
|------|-------------|----------------|
| **Slot** | 12-second time window for a block | 12 seconds |
| **Epoch** | Group of 6 slots | 72 seconds (6 x 12s) |
| **Validator** | Entity that proposes/attests blocks | 3 interop genesis validators (indices 0,1,2); more can join via real 32 ETH deposits |
| **Attestation** | Vote that a block is valid | Submitted every slot by active validators |
| **Sync Committee** | Group of validators providing light client data | rotates every epoch |
| **Engine API** | Interface between beacon and execution | `localhost:8551` with JWT auth |
| **forkchoiceUpdated** | Beacon tells Geth which head to build on | Called every slot |
| **getPayload** | Beacon requests Geth to build execution payload | Returns transactions + state root |
| **newPayload** | Beacon sends block to Geth for validation | Geth verifies state transition |

### Block Production Flow

```
Slot N begins (every 12 seconds)
    |
    v
Beacon selects proposer (validator index = slot % 3)
    |
    v
Beacon calls Engine API: forkchoiceUpdated(head, payloadAttributes)
    |
    v
Geth starts building execution payload (transactions, state root)
    |
    v
Beacon calls Engine API: getPayload(payloadID)
    |
    v
Geth returns execution payload
    |
    v
Beacon assembles full block (consensus + execution)
    |
    v
Beacon publishes block to network
    |
    v
Validators attest to block validity
    |
    v
Next slot begins
```

---

## Real Validator Deposits (Permissionless Staking)

This devnet includes a real Ethereum deposit contract at `0x4242424242424242424242424242424242424242`. Anyone who holds 32 devnet ETH can become a validator by calling the contract.

### How It Differs from Genesis Validators

| Genesis validators | Deposit validators |
|---|---|
| Injected into `genesis.ssz` at chain start | Created by a transaction to the deposit contract |
| No ETH actually moves on the execution layer | 32 ETH is transferred to the deposit contract |
| Controlled by the network operator | Can be created by anyone with 32 devnet ETH |
| Indices 0, 1, 2 | Starts at index 3 and grows |

### Deposit a New Validator

1. Generate deposit data with the [staking-deposit-cli](https://github.com/ethereum/staking-deposit-cli):
   ```bash
   ./deposit new-mnemonic --num_validators 1 --chain devnet --eth1_withdrawal_address 0x...
   ```
   This produces `deposit_data-*.json` containing your BLS pubkey, withdrawal credentials, signature, and deposit data root.

2. Place the file next to `send_deposit_new.py` and update `deposit_data_new.json` if needed.

3. Fund the sender account. The default sender is the Geth dev account `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`, which is pre-funded on this private chain. To use your own account, change `from_key` in `send_deposit_new.py`.

4. Send the deposit:
   ```bash
   cd ~/eth-pos/private-pos
   python3 send_deposit_new.py
   ```

5. Verify the beacon state picked it up:
   ```bash
   curl -s http://localhost:3500/eth/v1/beacon/states/head/validators | jq '.data | length'
   ```
   The count should increase from 3 to 4. After a few epochs the new validator becomes `active_ongoing`.

### What the Script Does

`send_deposit_new.py`:
- Connects to Geth on `http://localhost:8541`
- Reads `deposit_data_new.json`
- Builds a transaction calling `deposit(pubkey, withdrawal_credentials, signature, deposit_data_root)`
- Sends exactly 32 ETH to the deposit contract
- Waits for the receipt

### Example Output

```text
Sender: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
Amount (Gwei): 32000000000
Tx hash: 8fbc7c64b97e3b2643f0264d3444438b13e1c4c686da6ba548090d3675e0fbd9
Status: 1
Block: 22
```

### Notes

- The deposit contract verifies the BLS signature and `deposit_data_root`. Invalid deposits are rejected by the contract.
- The beacon chain only activates a validator after the deposit is processed by a beacon block and the activation queue reaches the new validator.
- This is **permissionless at the protocol level**, but users still need 32 devnet ETH. There is no faucet in this repo.

---

## Network Ports

### Geth Execution Nodes

| Node | HTTP RPC | Auth RPC (Engine) | P2P | Metrics |
|------|----------|-------------------|-----|---------|
| Geth 1 | `8541` | `8551` | `30301` | `6060` |
| Geth 2 | `8542` | `8552` | `30302` | `6061` |
| Geth 3 | `8543` | `8553` | `30303` | `6062` |

### Prysm Beacon Nodes

| Node | REST API | gRPC | P2P TCP | P2P UDP | RPC | Metrics |
|------|----------|------|---------|---------|-----|---------|
| Beacon 1 | `3500` | `4000` | `13000` | `12000` | `4000` | `8080` |
| Beacon 2 | `3501` | `4001` | `13001` | `12001` | `4001` | `8081` |
| Beacon 3 | `3502` | `4002` | `13002` | `12002` | `4002` | `8082` |

### Validator Clients

Validators connect to their respective beacon node via REST API (ports 3500-3502). No external ports needed.

**Total Active Ports:** 21 (9 processes x 2-3 ports each)

---

## Interacting with the Network

### Check Block Number

```bash
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://localhost:8541 | python3 -c "import sys,json; print('block:', int(json.load(sys.stdin)['result'],16))"
```

**Expected output:**
```
block: 42
```

### Get Block by Number

```bash
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest",true],"id":1}' \
  http://localhost:8541 | jq '.result | {number: .number, hash: .hash, timestamp: .timestamp, transactions: (.transactions | length)}'
```

### Check Chain ID

```bash
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  http://localhost:8541 | python3 -c "import sys,json; print('chainId:', int(json.load(sys.stdin)['result'],16))"
```

### Check Beacon Head

```bash
curl -s http://localhost:3500/eth/v1/beacon/headers/head | jq '.data | {slot: .slot, proposer: .proposer_index, root: .root}'
```

### Check Sync Status

```bash
# Geth sync status
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
  http://localhost:8541 | jq

# Beacon sync status
curl -s http://localhost:3500/eth/v1/node/syncing | jq
```

### Check Validator Status

```bash
# List all validators
curl -s http://localhost:3500/eth/v1/beacon/states/head/validators | jq '.data | length'

# Check specific validator (index 0)
curl -s http://localhost:3500/eth/v1/beacon/states/head/validators/0 | jq '.data | {index: .index, status: .status, balance: .balance}'
```

### Check Peer Counts

```bash
# Geth peers
curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"admin_peers","params":[],"id":1}' \
  http://localhost:8541 | jq '.result | length'

# Beacon peers
curl -s http://localhost:3500/eth/v1/node/peer_count | jq '.data.connected'
```

---

## Connecting MetaMask

1. **Open MetaMask** -> Click network dropdown -> **Add Network** -> **Add Network Manually**

2. **Fill in these exact values:**

| Field | Value |
|-------|-------|
| **Network Name** | `Private PoS Devnet` |
| **New RPC URL** | `http://localhost:8541` |
| **Chain ID** | `12345` |
| **Currency Symbol** | `ETH` |
| **Block Explorer URL** | *(leave empty)* |

3. **Save** -> You should see your pre-funded account balance (10,000 ETH)

**Note:** If MetaMask shows "Could not fetch chain ID", ensure Geth is running: `curl http://localhost:8541`

---

## Funding Accounts

### Pre-Funded Accounts (from genesis.json)

These accounts are funded with 10,000 ETH at genesis:

| Address | Balance |
|---------|---------|
| `0x8B0681dBD724dcaC48b433e9df8A220D47C94a19` | 10,000 ETH |
| `0x6Bd7f3AfB4f2B1E3f8d5C4E9A7B2C1D0E8F6A5B4` | 10,000 ETH |
| `0xA1B2C3D4E5F6789012345678901234567890ABCD` | 10,000 ETH |

### Transferring ETH

```bash
# Send 1 ETH from account 0 to account 1
curl -s -X POST -H "Content-Type: application/json" \
  --data '{
    "jsonrpc":"2.0",
    "method":"eth_sendTransaction",
    "params":[{
      "from": "0x8B0681dBD724dcaC48b433e9df8A220D47C94a19",
      "to": "0x6Bd7f3AfB4f2B1E3f8d5C4E9A7B2C1D0E8F6A5B4",
      "value": "0xDE0B6B3A7640000"
    }],
    "id":1
  }' http://localhost:8541
```

**Note:** `0xDE0B6B3A7640000` = 1 ETH in wei (10^18).

---

## Deploying Smart Contracts

### Hardhat Configuration

Create `hardhat.config.js`:

```javascript
require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  networks: {
    devnet: {
      url: "http://localhost:8541",
      chainId: 12345,
      accounts: [
        // Private key for 0x8B0681dBD724dcaC48b433e9df8A220D47C94a19
        "0x...", // Replace with actual private key
      ],
    },
  },
  solidity: "0.8.20",
};
```

Deploy:
```bash
npx hardhat run scripts/deploy.js --network devnet
```

### Foundry Configuration

Create `foundry.toml`:

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]

[rpc_endpoints]
devnet = "http://localhost:8541"
```

Deploy:
```bash
forge script script/Deploy.s.sol --rpc-url devnet --broadcast --private-key 0x...
```

---

## Monitoring Node Health

### What to Watch

| Log File | What to Look For | Bad Signs |
|----------|------------------|-----------|
| `logs/beacon1.log` | `Synced new block` | `ERROR` repeatedly, `state and block are different version` |
| `logs/geth1.log` | `Forkchoice updated` | `SYNCING`, `no peers` for extended periods |
| `logs/validator1.log` | `Submitted new block` | repeated `Sync Committee Message is too old` |

### Key Metrics Endpoints

```bash
# Beacon metrics (Prometheus format)
curl -s http://localhost:8080/metrics | grep "beacon_head_slot"

# Geth metrics
curl -s http://localhost:6060/debug/metrics/prometheus | grep "chain_head_block"
```

### Is the Chain Stuck?

```bash
# Check if block number is advancing
OLD=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://localhost:8541 | python3 -c "import sys,json; print(int(json.load(sys.stdin)['result'],16))")
sleep 15
NEW=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://localhost:8541 | python3 -c "import sys,json; print(int(json.load(sys.stdin)['result'],16))")

if [ "$NEW" -eq "$OLD" ]; then
  echo "CHAIN IS STUCK at block $OLD"
else
  echo "Chain advancing: $OLD -> $NEW"
fi
```

### Healthy Chain Indicators

:heavy_check_mark: `eth_blockNumber` increases every ~12 seconds
:heavy_check_mark: `beacon1.log` shows `Synced new block` with advancing slot numbers
:heavy_check_mark: `validator1.log` shows `Submitted new block` or `Submitted new attestations`
:heavy_check_mark: Geth logs show `Forkchoice updated` with `payloadAttributes`

---

## Performance Requirements

| Resource | Minimum | Recommended | Notes |
|----------|---------|-------------|-------|
| **RAM** | 4 GB | 8 GB | Geth + Prysm + validators together |
| **CPU** | 2 cores | 4 cores | Running is light; building not required |
| **Disk** | 2 GB free | 10 GB SSD | Chaindata grows slowly |
| **Network** | Localhost only | Localhost only | Not designed for external access |

**CPU Usage When Running:**
- 3x Geth: ~200-400 MB RAM each, low CPU
- 3x Prysm beacon: ~400-600 MB RAM each, moderate CPU
- 3x Validators: ~100 MB RAM each, very low CPU

---

## Security Warnings

:warning: **THIS NETWORK IS FOR LOCAL DEVELOPMENT ONLY**

| Risk | Mitigation |
|------|------------|
| **Interop validator keys** | These are publicly known deterministic keys. Never use on mainnet or testnet. |
| **JWT secret** | `jwt.hex` is shared across all nodes. On a real network, each pair would have unique secrets. |
| **No firewall** | Ports are bound to localhost, but if you expose them, anyone can interact with your node. |
| **No encryption** | All communication is unencrypted HTTP. |
| **Fake ETH** | All balances are worthless. Don't confuse with real ETH. |
| **Genesis manipulation** | Anyone with the genesis config can create a competing chain. |

**Never:**
- Expose RPC ports (8541, 3500) to the public internet
- Use interop keys on any public network
- Run this on a production server
- Send real ETH to any devnet address

---

## Single-Node Mode

For a lighter deployment on one machine, use `start-single-node.sh`:

```bash
cd ~/eth-pos/private-pos
./start-single-node.sh
```

This starts:
- 1 Geth execution node
- 1 Prysm beacon node
- 1 validator

Useful when you only need one node producing blocks, e.g. for an overnight run or a single-machine test before scaling out.

**Note:** Finality still requires 2/3 of validators online. With 9 total validators across the network, at least 6 must be running. Single-node mode is just for lightweight testing, not a complete distributed network.

---

## Joining the Network

This repository is configured as a **9-validator private Ethereum PoS devnet**. By default, validators are split across multiple participants, each running their own Geth + Prysm beacon + Prysm validator. The **Mac Mini is the permanent bootnode** (node 1). All other participants connect to it.

### How to get invited

1. Ask the network owner for an assigned **node number** (2-9).
2. The owner will give you:
   - The **bootnode IP** (Mac Mini address).
   - The **bootnode peer ID**.
   - Your validator **keystore directory**.
   - The shared **JWT secret** file.
3. Follow the step-by-step guide in [`JOIN.md`](JOIN.md).

### Quick start for participants

```bash
# 1. Install dependencies and binaries
./download-binaries.sh

# 2. Copy the example config and fill it in
cp node-config.example.env node-config.env
nano node-config.env

# 3. Place your keystore and JWT secret in the repo folder
#    (keystore/ and jwt-secret)

# 4. Start your node
./join-network.sh
```

See `JOIN.md` for full Windows (WSL), Mac, and Linux instructions, including troubleshooting and health checks.

---

## Troubleshooting

### Fork Version Mismatch: `state and block are different version. 4 != 6`

**Error Message:**
```
ERROR blockchain: Could not validate block state root error=state and block are different version. 4 != 6
```

**Root Cause:** `genesis.ssz` was generated with `--fork deneb` (state version 4), but `config.yaml` has `ELECTRA_FORK_EPOCH: 0`, so Prysm expects Electra blocks (version 6).

**Fix:**
```bash
# In run-pos.sh, change:
./prysmctl testnet generate-genesis --fork deneb
# To:
./prysmctl testnet generate-genesis --fork electra
```

Then run `./run-pos.sh` for a full reset.

---

### Cached Genesis in Beacon Datadir

**Symptom:** After regenerating genesis, Prysm still uses old genesis state root.

**Root Cause:** Prysm caches genesis state in `beacon1/beaconchaindata/`.

**Fix:**
```bash
# Wipe all beacon data
rm -rf beacon1/* beacon2/* beacon3/*
# Then restart
./start-all.sh
```

Or simply run `./run-pos.sh` which wipes everything.

---

### `terminalTotalDifficultyPassed` Missing

**Error Message:**
```
Fatal: invalid genesis file: terminalTotalDifficultyPassed must be set
```

**Root Cause:** Geth v1.14.0+ requires `terminalTotalDifficultyPassed` in genesis.json.

**Fix:** Add to `genesis.json` under `config`:
```json
"terminalTotalDifficultyPassed": true
```

---

### `blobSchedule` Missing for Cancun/Prague

**Error Message:**
```
Fatal: invalid genesis file: blobSchedule missing for cancun
```

**Root Cause:** Geth v1.14.0+ requires `blobSchedule` when `cancunTime` is set.

**Fix:** Add to `genesis.json` under `config`:
```json
"blobSchedule": {
  "cancun": {"target": 3, "max": 6, "baseFeeUpdateFraction": 3338477},
  "prague": {"target": 6, "max": 9, "baseFeeUpdateFraction": 5007716}
}
```

---

### `terminalTotalDifficulty` Wrong Type (string vs int)

**Error Message:**
```
Fatal: invalid genesis file: terminalTotalDifficulty must be a number, not a string
```

**Root Cause:** Geth expects `terminalTotalDifficulty` as an integer, not a hex string.

**Fix:** Use `"terminalTotalDifficulty": 0` (no quotes, no `0x` prefix).

---

### Geth Peering Broken (IPC Disabled)

**Symptom:** Geth nodes show 0 peers even after startup.

**Root Cause:** `start-all.sh` used `geth attach --exec "admin.addPeer"` but `--ipcdisable` is set, so IPC is unavailable.

**Error:**
```
Fatal: Unable to attach to remote geth: no known transport for IPC endpoint
```

**Fix:** Use HTTP RPC for peering:
```bash
ENODE1=$(curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"admin_nodeInfo","params":[],"id":1}' \
  http://localhost:8541 | python3 -c "import sys,json; e=json.load(sys.stdin)['result']['enode']; print(e.replace(e.split('@')[1].split(':')[0],'127.0.0.1'))")

curl -s -X POST -H "Content-Type: application/json" \
  --data "{\"jsonrpc\":\"2.0\",\"method\":\"admin_addPeer\",\"params\":[\"$ENODE2\"],\"id\":1}" \
  http://localhost:8541
```

This is now fixed in `start-all.sh`.

---

### Beacon Peering Race Condition

**Symptom:** Beacon2 and Beacon3 start with `--bootstrap-node=` (empty), never find peers.

**Root Cause:** `start-all.sh` captures beacon1's peer ID immediately after starting it, but the HTTP API isn't ready yet.

**Fix:** Added retry loop in `start-all.sh`:
```bash
for i in $(seq 1 30); do
  BEACON1_PEER=$(curl -s http://localhost:3500/eth/v1/node/identity 2>/dev/null | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data']['peer_id'])")
  if [ -n "$BEACON1_PEER" ]; then
    echo "Got beacon1 peer ID: $BEACON1_PEER"
    break
  fi
  sleep 1
done
```

---

### Genesis Timestamp in the Past

**Symptom:** Prysm shows negative countdown or genesis already passed.

**Root Cause:** Hardcoded old timestamp in `run-pos.sh` or `genesis.json`.

**Fix:** Use dynamic timestamp:
```bash
GENESIS_TIME=$(($(date +%s) + 180))  # 3 minutes from now
```

Then update `genesis.json`:
```bash
python3 << 'PYEOF'
import json
g = json.load(open('genesis.json'))
g['timestamp']='0x$(printf '%x' $GENESIS_TIME)'
json.dump(g, open('genesis.json','w'), indent=2)
PYEOF
```

---

### Validator Count Mismatch

**Symptom:** Only 3 validators active, but `MIN_GENESIS_ACTIVE_VALIDATOR_COUNT` is 64.

**Explanation:** This is **by design**. The `prysmctl generate-genesis` command creates 3 validators in the genesis state, and all 3 are actively running. `MIN_GENESIS_ACTIVE_VALIDATOR_COUNT` is a network parameter that does not need to match the actual validator count on this devnet.

**Impact:** The chain progresses normally with 3 active validators.

---

### Sync Committee Messages Too Old

**Warning Message:**
```
WARN p2p: Sync Committee Message is too old to broadcast, discarding it
error=sync message is too late
```

**Explanation:** This is **expected** when beacon nodes have 0 peers. Sync committee messages are time-sensitive and must be broadcast within the same slot. With no peers, the message sits in the queue until the slot passes, then is discarded.

**Impact:** Minimal. The chain still produces blocks. Sync committee duties are for light clients, which don't exist on this local devnet.

**Fix:** Optional — connect beacon peers (see beacon peering fix above).

---

### `prysmctl` Overwrites `genesis.json`

**Symptom:** Custom edits to `genesis.json` (like `terminalTotalDifficultyPassed`) are lost after running `prysmctl generate-genesis`.

**Root Cause:** `prysmctl` regenerates `genesis.json` from its template, overwriting manual changes.

**Fix:** Apply patches AFTER `prysmctl` runs. In `run-pos.sh`:
```bash
# Generate genesis
./prysmctl testnet generate-genesis --fork electra ...

# THEN apply fixes
python3 << 'PYEOF'
import json
g = json.load(open('genesis.json'))
g['config']['terminalTotalDifficultyPassed'] = True
g['config']['terminalTotalDifficulty'] = 0
# ... other fixes ...
json.dump(g, open('genesis.json','w'), indent=2)
PYEOF
```

---

### Fulu Fork Not Supported

**Error Message:**
```
ERROR blockchain: received an undefined execution engine error error=Unsupported fork
```

**Root Cause:** Geth v1.15.11 does not support building Fulu payloads in this interop configuration, or Prysm v5.3.2 cannot load a Fulu genesis state at runtime.

**Fix:** Disable Fulu by setting `FULU_FORK_EPOCH: 18446744073709551615` in `config.yaml` and generate genesis with `--fork electra`.

---

### GLOAS Fork Unknown to prysmctl

**Error Message:**
```
yaml: unmarshal errors: line 58: field GLOAS_FORK_VERSION not found
```

**Root Cause:** Prysm v5.3.2 does not recognize the `GLOAS` fork fields.

**Fix:** Remove `GLOAS_FORK_VERSION` and `GLOAS_FORK_EPOCH` from `config.yaml`.

---

## Full Reset Procedure

To completely wipe the network and start fresh:

```bash
cd ~/eth-pos/private-pos

# 1. Stop all processes
./stop-all.sh
# Or manually: pkill -f geth; pkill -f prysm.sh; sleep 2; pkill -9 -f geth; pkill -9 -f prysm.sh

# 2. Wipe all data directories
rm -rf node1/geth/* node2/geth/* node3/geth/*
rm -rf beacon1/* beacon2/* beacon3/*
rm -rf validator1/* validator2/* validator3/*

# 3. Remove old genesis files
rm -f genesis.json genesis.ssz

# 4. Regenerate everything and start
./run-pos.sh
```

**What `run-pos.sh` does:**
1. Generates `jwt.hex` if missing
2. Generates `genesis.ssz` (consensus genesis with `--fork electra`)
3. Generates `genesis.json` (execution genesis)
4. Applies fixes (`terminalTotalDifficultyPassed`, `blobSchedule`, etc.)
5. Initializes Geth nodes with new genesis
6. Starts all 9 processes with proper peering

---

## Extending the Network

### Adding More Validators

1. **Generate new validator keys:**
```bash
./prysm.sh validator accounts create --wallet-dir=../new-validator --num-accounts=1
```

2. **Add to genesis:** Regenerate `genesis.ssz` with more validators:
```bash
./prysmctl testnet generate-genesis --num-validators=100 ...
```

3. **Start new validator:**
```bash
./prysm.sh validator --beacon-rest-api-provider=http://localhost:3500 \
  --wallet-dir=../new-validator --interop-start-index=3
```

### Adding More Nodes

The scripts now support `NUM_NODES`:

```bash
bash regen-and-restart.sh 4
bash start-all.sh 4
```

For 9 nodes on 9 separate machines, use `distributed-start.sh`.

---

## Distributed Deployment (9 Nodes on 9 Machines)

Each machine runs one full node: **Geth + Prysm beacon + Prysm validator**.

### Files to copy to every machine

Copy these exact files from the genesis machine to every target machine:

```bash
config.yaml
genesis.json
genesis.ssz
jwt.hex
```

Also copy the binaries:

```bash
geth-1.17.4
beacon-chain-v5.3.2
validator-v5.3.2
```

### 1. Generate a 9-validator genesis on the genesis machine

```bash
bash regen-and-restart.sh 9
```

This creates `genesis.json` and `genesis.ssz` for 9 validators. **Do not run this** if you already have a live network you want to keep — it wipes and regenerates.

### 2. Start the seed node (machine 1)

```bash
export NODE_ID=1
export MACHINE_IP=10.0.0.1
bash distributed-start.sh
```

After beacon1 starts, get its peer ID and P2P port:

```bash
curl -s http://10.0.0.1:3500/eth/v1/node/identity | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print('PEER_ID='+d['data']['peer_id']); print('ENR='+d['data']['enr'])"
```

The P2P port is `13000` by default for machine 1.

You can also copy the helper script and fill the seed peer ID:

```bash
bash copy-to-node.sh 2 root@10.0.0.2
```

### 3. Start machines 2–9

On each machine, set the seed node details and its own IP:

```bash
export NODE_ID=2
export MACHINE_IP=10.0.0.2
export SEED_BEACON_IP=10.0.0.1
export SEED_BEACON_P2P_PORT=13000
export SEED_BEACON_PEER_ID=16Uiu2HAk...
bash distributed-start.sh
```

Repeat for `NODE_ID=3..9` with unique IPs. Each machine uses different ports based on `NODE_ID`.

### Network layout

| Machine | Node ID | IP | Geth HTTP | Engine API | Beacon REST | Beacon P2P TCP | Beacon P2P UDP |
|---------|---------|-----|-----------|------------|-------------|----------------|----------------|
| 1 | 1 | 10.0.0.1 | 8541 | 8551 | 3500 | 13000 | 12000 |
| 2 | 2 | 10.0.0.2 | 8542 | 8552 | 3501 | 13001 | 12001 |
| ... | ... | ... | ... | ... | ... | ... | ... |
| 9 | 9 | 10.0.0.9 | 8549 | 8559 | 3509 | 13008 | 12008 |

### Firewall ports to open between machines

| Port Range | Purpose | Restrict to |
|------------|---------|-------------|
| 30301-30309 | Geth P2P | All nodes |
| 13000-13008 | Beacon P2P TCP | All nodes |
| 12000-12008 | Beacon P2P UDP | All nodes |
| 8551-8559 | Engine API | Localhost only per machine |
| 3500-3509 | Beacon REST API | Local validator / monitoring |
| 8541-8549 | Geth HTTP | Monitoring only |

### Important notes

- **Never** expose Geth HTTP (`854x`) or Engine API (`855x`) to the public internet without a proxy or firewall.
- All 9 machines must share the exact same `genesis.json` and `genesis.ssz`.
- Each machine should have at least **4 CPU cores and 8 GB RAM**.
- For a public deployment, use a VPN, private network, or authenticated RPC gateway.

### Changing Fork Epochs

Edit `config.yaml`:
```yaml
# Delay Fulu to epoch 10
FULU_FORK_EPOCH: 10
```

Then run `./run-pos.sh` for full reset. The chain will start with earlier forks and upgrade at the specified epoch.

---

## Known Limitations

| Limitation | Explanation | Workaround |
|------------|-------------|------------|
| **0 beacon peers** | Beacon2/3 show 0 peers | Non-critical for local devnet; validators connect via REST API |
| **Interop keys only** | No real deposit contract | For testing only; never use on public networks |
| **Local only** | Not discoverable on internet | Use VPN or port forwarding for remote access (not recommended) |
| **No block explorer** | No Etherscan equivalent | Use `curl` queries or build a local explorer |
| **No MEV** | No builder market | Direct beacon->execution block building |
| **Fast epochs** | 72-second epochs | Mainnet is 6.4 minutes; timing-sensitive tests may behave differently |
| **Fulu disabled** | Fulu fork is set to max epoch | Re-enable only if using Geth/Prysm versions that fully support Fulu interop |

---

## Changelog

### v1.3.0 — 2026-06-29
- **Auto-download Prysm v5.3.2 binaries** (`beacon-chain`, `validator`, `prysmctl`) on first run
- **Remove stale `genesis.ssz`/`genesis.json`** before regenerating
- **Create `logs/` directory** automatically
- **Removed pre-built binary artifacts** from repo (Geth and Prysm are downloaded on demand)

### v1.2.0 — 2026-06-29
- **Upgraded Geth to v1.17.4** (latest stable)
- Kept Prysm v5.3.2 and Electra genesis
- Verified block production with Geth 1.17.4

### v1.1.0 — 2026-06-29
- **Pinned Prysm to v5.3.2** (downloaded binaries via `prysm.sh`)
- **Pinned Geth to v1.15.11** (pre-built binary)
- **Disabled Fulu fork** (`FULU_FORK_EPOCH: max`) to avoid `Unsupported fork` and genesis-state runtime errors
- **Removed GLOAS fork fields** (not recognized by Prysm v5.3.2)
- **Removed Osaka blob schedule** (not needed without Fulu)
- **Updated genesis generation** to use `--fork electra`
- **Verified block production** with head slot 99+ and finalized epoch 14+

### v1.0.0 — 2026-06-26
- **Initial working version**
- Fixed fork version mismatch (`--fork deneb` -> `--fork fulu`)
- Added `terminalTotalDifficultyPassed: true` for Geth v1.14.0+
- Added `blobSchedule` for Cancun/Prague/Osaka
- Fixed Geth peering via HTTP `admin_addPeer`
- Fixed beacon peering race condition with retry loop
- Verified block production: slots 0-5+ with execution payloads
- All 3 validators submitting attestations, sync messages, and blocks

---

## License

MIT License — see [LICENSE](LICENSE) file for details.

```
Copyright (c) 2026

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## Contributors

| Role | Contribution |
|------|--------------|
| **Harsh** | Network architecture, configuration, troubleshooting |
| **Prysm Team** | Consensus client (prysmaticlabs/prysm) |
| **Geth Team** | Execution client (ethereum/go-ethereum) |

---

## Additional Resources

- [Ethereum Consensus Specs](https://github.com/ethereum/consensus-specs)
- [Prysm Documentation](https://docs.prylabs.network/)
- [Geth Documentation](https://geth.ethereum.org/docs/)
- [Engine API Specification](https://github.com/ethereum/execution-apis/blob/main/src/engine/paris.md)
- [Interop Guidelines](https://notes.ethereum.org/@djrtwo/rym-eth2-interop)

---

*Last updated: 2026-06-29*
