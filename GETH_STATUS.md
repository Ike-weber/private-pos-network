# Geth Implementation Status — Private PoS Devnet

This file tracks what is complete and what is still missing for Geth in this private PoS devnet.

---

## Completed

### Core Execution Client
- [x] Geth v1.17.4-stable running.
- [x] Custom `genesis.json` with chain ID `12345`, PoS transition, and fork timestamps.
- [x] `--networkid 12345` enforced.
- [x] `--syncmode full` configured.
- [x] `--state.scheme path` configured.
- [x] `--snapshot` enabled.
- [x] Genesis block writes correctly to all node datadirs.

### Fork Support
- [x] Shanghai, Cancun, Prague forks active from genesis.
- [x] `blobSchedule` configured for Cancun and Prague.
- [x] `terminalTotalDifficulty` set to `0`.
- [x] `terminalTotalDifficultyPassed` set to `true`.
- [x] `depositContractAddress` set to `0x4242424242424242424242424242424242424242`.

### Engine API / Consensus Integration
- [x] Engine API enabled with JWT secret (`jwt.hex`).
- [x] Prysm beacon nodes connect via `--execution-endpoint`.
- [x] Payload execution, forkchoice updates, and block production working.
- [x] Deposit contract bytecode stripped from execution genesis so EL/CL genesis roots match.

### HTTP / WebSocket / Auth RPC
- [x] HTTP RPC enabled on per-node ports (`8541`, `8542`, ...).
- [x] WS RPC enabled on per-node ports (`8551`, `8552`, ...).
- [x] Auth RPC enabled on per-node ports (`8561`, `8562`, ...) for Engine API.
- [x] `--http.api` and `--ws.api` include `eth,net,web3,engine,admin,debug,txpool`.
- [x] `--http.vhosts '*'` and `--http.corsdomain '*'` set for local development.
- [x] `--ipcdisable` set to avoid IPC socket issues.

### Local Peering
- [x] 3 Geth nodes peered on localhost.
- [x] Static enode list generated and `admin_addPeer` loop used for peering.
- [x] Peer counts verified via `admin_peers`.

### Bootnode Peering (Local Test)
- [x] `start-with-bootnode.sh` created.
- [x] Bootnode-based discovery tested with 3 local Geth nodes.
- [x] All nodes discovered each other through one bootstrap node.
- [x] No manual `admin_addPeer` needed.

### Multi-Node Startup
- [x] `start-all.sh` launches up to 9 Geth + beacon + validator processes.
- [x] `start-single-node.sh` launches a lightweight 1-node deployment.
- [x] `nohup` used so daemons survive shell exit.
- [x] Per-node ports and datadirs managed automatically.

### Real Deposit Contract
- [x] Standard Ethereum deposit contract deployed at `0x424242...4242`.
- [x] Real 32 ETH deposit transaction proven on a previous chain run.
- [x] `send_deposit_new.py` submits deposits via `deposit(pubkey, withdrawal_credentials, signature, deposit_data_root)`.
- [x] Deposit contract verifies BLS signature and `deposit_data_root`.

### Metrics
- [x] `--metrics --metrics.addr 127.0.0.1 --metrics.port` enabled per node.
- [x] Prometheus-compatible metrics available on `6061`, `6062`, ...

---

## Missing / Not Implemented

### Public P2P Discovery
- [ ] Geth nodes bound only to `127.0.0.1` and local network.
- [ ] No public IP binding (`--nat extip:<public-ip>` only tested locally).
- [ ] No static public bootnode with a public IP.
- [ ] No DNS discovery (`--discovery.dns`).
- [ ] No enode published for external peers to join.
- [ ] Firewall / router port-forwarding not configured.

### RPC Security
- [ ] No HTTP RPC authentication.
- [ ] No TLS / HTTPS for RPC.
- [ ] No rate limiting.
- [ ] No IP allowlist / network restriction beyond local.
- [ ] No RPC method allowlist (admin/debug exposed).
- [ ] `--http.corsdomain '*'` and `--http.vhosts '*'` are insecure for production.
- [ ] Auth RPC vhosts not restricted to trusted clients.

### Sync Modes
- [ ] Only `--syncmode full` used; snap sync not tested.
- [ ] `--gcmode archive` used; full/pruned mode not tested.
- [ ] No checkpoint sync configured.
- [ ] No light client support.

### Database Maintenance
- [ ] No online pruning strategy tested.
- [ ] No corruption recovery procedure.
- [ ] No automated chaindata backup.
- [ ] No disk-usage monitoring or rotation.
- [ ] No `--cache` tuning for different hardware.

### Monitoring / Alerting
- [ ] Metrics exposed but not scraped by Prometheus.
- [ ] No Grafana dashboards.
- [ ] No alerts for:
  - sync lag,
  - peer count drop,
  - block production stall,
  - high memory/disk usage,
  - errors in logs.
- [ ] No centralized log aggregation.

### Multi-Machine / Multi-Client
- [ ] Geth nodes not deployed on separate hosts.
- [ ] No second execution client (Besu / Nethermind) for client diversity.
- [ ] No NAT traversal or VPN setup.
- [ ] See `NOT COVERED` note — intentionally out of scope for now.

### Upgrade / Governance
- [ ] No documented Geth upgrade process.
- [ ] No rollback procedure.
- [ ] No hard-fork coordination workflow.
- [ ] No version pinning beyond current `v1.17.4`.

### Resource Management
- [ ] No CPU / memory limits set (e.g. `systemd` limits, cgroups, Docker).
- [ ] No disk quotas.
- [ ] No bandwidth limits.
- [ ] No `ulimit` tuning documented.

### Production Hardening
- [ ] `--http.addr 127.0.0.1` is good but needs to be enforced for all APIs.
- [ ] Engine API JWT secret should be rotated periodically.
- [ ] No secrets management (JWT keys stored in repo).
- [ ] No node key (`--nodekey`) management for stable peer identity.
- [ ] No separate data directory permissions (everything owned by user).
- [ ] No DoS protection on RPC or P2P ports.

### MEV / Builder Support
- [ ] No builder API (`--builder` flags).
- [ ] No PBS (proposer-builder separation) testing.
- [ ] No MEV-boost integration.

### Resilience / Failure Testing
- [ ] No crash-recovery testing.
- [ ] No network partition simulation.
- [ ] No clock skew testing.
- [ ] No corrupt genesis / chaindata recovery.
- [ ] No graceful shutdown procedure.

---

## How to Use This File

When you implement a missing item:
1. Move its bullet from **Missing** to **Completed**.
2. Add a brief note or link to the relevant script/config.
3. Commit this file.

When Geth is considered operationally complete for this devnet, the **Missing** section should be empty (except for intentionally out-of-scope items like multi-machine/multi-client, which should stay marked `NOT COVERED`).

---

## Notes

- This is a local devnet. Production-level RPC exposure and public peering are intentionally limited.
- Multi-machine deployment and multi-client diversity are explicitly out of scope for this stage.
- The main remaining operational tasks before scaling validators are: sync modes, RPC security, monitoring, database maintenance, and upgrade process.
