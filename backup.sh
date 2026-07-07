#!/bin/bash
set -e

# backup.sh — backup Geth/Prysm datadirs and chain metadata
# Usage: ./backup.sh [label]

cd "$(dirname "$0")"
LABEL="${1:-$(date +%Y%m%d-%H%M%S)}"
BACKUP_DIR="backups/${LABEL}"
mkdir -p "$BACKUP_DIR"

echo "==> Stopping devnet processes for consistent backup"
./stop-all.sh || true
sleep 3

echo "==> Backing up datadirs"
for i in $(seq 1 9); do
  if [ -d "node${i}/geth" ]; then
    tar czf "${BACKUP_DIR}/node${i}.tar.gz" "node${i}/geth"
  fi
  if [ -d "beacon${i}" ]; then
    tar czf "${BACKUP_DIR}/beacon${i}.tar.gz" "beacon${i}"
  fi
  if [ -d "beacon${i}/validator" ]; then
    tar czf "${BACKUP_DIR}/validator${i}.tar.gz" "beacon${i}/validator"
  fi
done

echo "==> Backing up genesis + config"
cp -p genesis.json genesis.ssz config.yaml rpc-users.txt rpc-cert.pem rpc-key.pem "$BACKUP_DIR/" 2>/dev/null || true

echo "==> Backup complete: $BACKUP_DIR"
ls -lh "$BACKUP_DIR"
