# Private PoS Devnet Status

A fully local, single-machine Ethereum Proof-of-Stake devnet running Geth + Prysm with a real deposit contract, interop genesis validators, and working consensus.

---

## What We Have Implemented

### Network
- **Chain ID:** `12345`
- **Preset:** Interop (minimal config)
- **Block time:** 12 seconds
- **Slots per epoch:** 6
- **Forks active from genesis:** Altair, Bellatrix, Capella, Deneb, Electra
- **Fulfillment:** Not active

### Clients
- **Execution client:** Geth v1.17.4-stable
- **Consensus client:** Prysm v5.3.2
- **Validator client:** Prysm validator v5.3.2

### Topology
- Up to **9 nodes** configurable via `start-all.sh`
- Each node = Geth + Prysm beacon + Prysm validator
- Currently running **4 validators** (indices 0–3), all active
- Validators 0–2 = interop genesis validators
- Validator 3 = part of current genesis state (pre-injected)

### Deposit Contract
- **Address:** `0x4242424242424242424242424242424242424242`
- Standard Ethereum deposit contract deployed at genesis
- Real 32 ETH deposit transaction **proven on a previous chain run**
- `send_deposit_new.py` + `deposit_data_new.json` included for new deposits

### Genesis & Startup
- `run-pos.sh` generates `genesis.ssz`, `genesis.json`, and `config.yaml`
- Deposit contract bytecode is stripped from execution genesis so EL and CL genesis roots match
- `start-all.sh` launches all daemons with `nohup`
- `start-single-node.sh` for lightweight 1-node deployments

### Peering & Networking
- Local Geth peering via static enodes + `admin_addPeer`
- Local bootnode test (`start-with-bootnode.sh`) proven: 3 nodes discover each other through one bootstrap node
- Prysm beacon nodes peer statically to `beacon1`

### Consensus
- Engine API with JWT authentication
- PoS block production and attestation working
- Finality achieved with active validators

### RPC / APIs
- Geth HTTP, WebSocket, Auth, and metrics endpoints per node
- Prysm REST API exposed per beacon node
- MetaMask can connect via `http://localhost:8541`, chain ID `12345`

### Real Deposits
- Mechanism tested and working
- Current chain instance has 4 genesis validators; real deposits can be sent on any fresh run

---

## What Is Lacking vs Market PoS Networks

### Network Maturity
- **Localhost only** — not reachable from the public internet
- **Static peering** — no production-grade discovery (DNS, discv5, public bootnodes)
- **No client diversity** — only Geth + Prysm; no Besu/Nethermind/Lighthouse/Nimbus/etc.
- **No multi-machine deployment** — everything runs on one WSL machine

### Economic Security
- **Devnet ETH has no value** — no real economic incentive to behave honestly
- **No slashing risk** — validators cannot lose real money
- **No MEV / PBS** — no proposer-builder separation, no MEV-boost
- **No restaking / liquid staking** — EigenLayer, Lido-type mechanisms not implemented

### Validator Onboarding
- **Current genesis set is interop** — not real staking keys
- **Real deposits tested but not the default** — every fresh run currently starts with genesis validators
- **Goal:** scale to 9 validators, all based on real deposits (requires at least 1 bootstrap validator)

### Operations & Tooling
- **No public RPC security** — no TLS, auth tokens, rate limiting, or IP allowlists
- **No monitoring stack** — Prometheus not scraping, no Grafana dashboards, no alerts
- **No backup / recovery** — chaindata not backed up, no corruption recovery tested
- **No sync mode testing** — only full/archive mode used
- **No upgrade process** — no documented procedure for Geth or Prysm updates
- **No resource limits** — no cgroups, systemd limits, or quotas

### Resilience
- **No failure testing** — no crash recovery, network partition, or clock skew tests
- **No graceful shutdown** — processes killed directly with `stop-all.sh`
- **No node identity management** — no stable nodekeys

### Governance
- **No fork coordination** — manual genesis/config changes only
- **No on-chain voting** — no validator governance mechanism
- **No multi-sig or admin controls** — beyond pre-funded accounts in genesis

---

## Compared to a Real Production PoS Network (e.g. Ethereum Mainnet)

| Area | This Devnet | Production PoS Network |
|------|-------------|------------------------|
| Validator count | 4 (goal: 9) | Hundreds of thousands |
| Client diversity | Geth + Prysm only | Multiple EL + CL clients |
| Economic security | Fake ETH | Real ETH at stake |
| Slashing | No real penalty | Real penalty up to full stake |
| Network reach | Localhost | Global, permissionless peers |
| Discovery | Static / local bootnode | discv5 + DNS + public bootnodes |
| MEV / PBS | Not implemented | MEV-boost, relays, builders |
| Monitoring | Metrics exposed only | Full observability + alerting |
| RPC security | Open local | TLS, auth, rate limits, allowlists |
| Upgrades | Manual | Coordinated hard forks + soft forks |

---

## What "Done" Looks Like for This Stage

1. Geth operationally hardened: sync modes, RPC security, monitoring, pruning.
2. Real deposit validators become the default onboarding path.
3. Scale to 9 real deposit validators (likely with 1 bootstrap validator).
4. Clean separation between local devnet and any future multi-machine plan.

Multi-machine deployment and multi-client diversity are explicitly **out of scope** for this stage.
