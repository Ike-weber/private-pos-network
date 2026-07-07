# Upgrade / Rollback Process — Private PoS Devnet

## Geth Upgrade

1. Download new Geth binary to `~/eth-pos/private-pos/`:
   ```bash
   wget https://gethstore.blob.core.windows.net/builds/geth-linux-amd64-<version>-<commit>.tar.gz
   tar xzf geth-linux-amd64-<version>-<commit>.tar.gz
   mv geth-linux-amd64-<version>-<commit>/geth ./geth-<version>
   chmod +x ./geth-<version>
   ```

2. Back up current chaindata:
   ```bash
   ./backup.sh pre-geth-upgrade
   ```

3. Stop the devnet:
   ```bash
   ./pos.sh stop
   ```

4. Update the `geth` symlink:
   ```bash
   ln -sf geth-<version> geth
   ```

5. Restart:
   ```bash
   ./pos.sh start   # or resume once implemented
   ```

6. Verify:
   ```bash
   ./pos.sh status
   ./pos.sh logs geth 1 30
   ```

## Prysm Upgrade

1. Download new Prysm binaries into `dist/`:
   ```bash
   PRYSM_VERSION=vX.Y.Z
   mkdir -p dist
   for bin in beacon-chain validator prysmctl; do
     curl -L --fail -o dist/${bin}-${PRYSM_VERSION}-linux-amd64 \
       https://github.com/OffchainLabs/prysm/releases/download/${PRYSM_VERSION}/${bin}-${PRYSM_VERSION}-linux-amd64
     chmod +x dist/${bin}-${PRYSM_VERSION}-linux-amd64
   done
   ```

2. Back up datadirs:
   ```bash
   ./backup.sh pre-prysm-upgrade
   ```

3. Stop the devnet:
   ```bash
   ./pos.sh stop
   ```

4. Update symlinks in `run-pos.sh`, `start-all.sh`, and `pos.sh` from `v5.3.2` to `vX.Y.Z`.

5. Restart and verify.

## Rollback

If the new version fails:

1. Stop the devnet:
   ```bash
   ./pos.sh stop
   ```

2. Restore datadirs from the backup taken before upgrade:
   ```bash
   BACKUP=backups/pre-geth-upgrade
   for i in $(seq 1 9); do
     rm -rf node${i}/geth beacon${i}
     tar xzf ${BACKUP}/node${i}.tar.gz
     tar xzf ${BACKUP}/beacon${i}.tar.gz
   done
   ```

3. Revert symlink or binary reference to the previous version.

4. Restart and verify.

## General Rules

- Always run `./backup.sh` before any upgrade.
- Never upgrade Geth and Prysm at the same time; do one, verify finality, then the other.
- After restart, wait for at least 2 finalized epochs before considering the upgrade successful.
- Keep previous binaries in the directory until the upgrade is confirmed stable.
