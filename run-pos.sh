#!/bin/bash
set -e

cd "$(dirname "$0")"
export USE_PRYSM_VERSION=v5.3.2
# Allow Prysm to fall back to unverified binaries if signatures/checksums are unavailable
export PRYSM_ALLOW_UNVERIFIED_BINARIES=1

# ── 0. DOWNLOAD GETH IF MISSING ─────────────────────────────────
GETH_VERSION="1.17.4"
GETH_COMMIT="36a7dc72"
GETH_BIN="./geth-${GETH_VERSION}"

if [ ! -x "$GETH_BIN" ]; then
  echo "Downloading Geth ${GETH_VERSION}..."
  TMP_TGZ="geth-${GETH_VERSION}.tar.gz"
  TMP_DIR="geth-linux-amd64-${GETH_VERSION}-${GETH_COMMIT}"

  # Primary: Azure build store
  AZURE_URL="https://gethstore.blob.core.windows.net/builds/geth-linux-amd64-${GETH_VERSION}-${GETH_COMMIT}.tar.gz"
  # Fallback: GitHub release asset (pattern used by Geth releases)
  GITHUB_URL="https://github.com/ethereum/go-ethereum/releases/download/v${GETH_VERSION}/geth-linux-amd64-${GETH_VERSION}-${GETH_COMMIT}.tar.gz"

  DOWNLOADED=false
  for URL in "$AZURE_URL" "$GITHUB_URL"; do
    echo "Trying $URL ..."
    if curl -L --fail --max-time 120 "$URL" -o "$TMP_TGZ" 2>/dev/null; then
      DOWNLOADED=true
      break
    else
      echo "  failed, trying next source..."
    fi
  done

  if [ "$DOWNLOADED" != "true" ]; then
    echo "ERROR: Could not download Geth ${GETH_VERSION} automatically."
    echo "Please download it manually from:"
    echo "  https://gethstore.blob.core.windows.net/builds/geth-linux-amd64-${GETH_VERSION}-${GETH_COMMIT}.tar.gz"
    echo "Then extract and place the 'geth' binary at: $GETH_BIN"
    exit 1
  fi

  tar xzf "$TMP_TGZ"
  mv "${TMP_DIR}/geth" "$GETH_BIN"
  chmod +x "$GETH_BIN"
  rm -rf "$TMP_DIR" "$TMP_TGZ"
  echo "Geth ${GETH_VERSION} ready"
fi

# ── 1. KILL EVERYTHING ──────────────────────────────────────────
pkill -9 -f geth || true
pkill -9 -f prysm.sh || true
pkill -9 -f beacon-chain || true
pkill -9 -f validator || true
sleep 3
pgrep -f "geth|prysm.sh|beacon-chain|validator" && echo "STALE PROCESSES!" && exit 1

# ── 2. WIPE ALL DATA ────────────────────────────────────────────
rm -rf beacon1/* beacon2/* beacon3/*
rm -rf validator1/* validator2/* validator3/*
for node in node1 node2 node3; do
  rm -rf $node/geth
  mkdir -p $node/geth
done

# ── 3. SET GENESIS TIME ──────────────────────────────────────────
GENESIS_TIME=$(( $(date +%s) + 180 ))
echo "Genesis at: $GENESIS_TIME = $(date -d @$GENESIS_TIME)"

# ── 4. GENERATE genesis.ssz ─────────────────────────────────────
./prysmctl-v5.3.2 testnet generate-genesis \
  --fork electra \
  --num-validators 3 \
  --genesis-time $GENESIS_TIME \
  --chain-config-file config.yaml \
  --geth-genesis-json-in genesis.json.working \
  --geth-genesis-json-out genesis.json \
  --output-ssz genesis.ssz

# ── 5. FIX genesis.json AFTER prysmctl ───────────────────────────
python3 -c "
import json
g = json.load(open('genesis.json'))
g['config']['terminalTotalDifficultyPassed'] = True
g['config']['terminalTotalDifficulty'] = 0
print('timestamp:', g.get('timestamp'))
print('terminalTotalDifficultyPassed:', g['config'].get('terminalTotalDifficultyPassed'))
json.dump(g, open('genesis.json', 'w'), indent=2)
print('genesis.json fixed')
"

# ── 6. INIT GETH ─────────────────────────────────────────────────
for node in node1 node2 node3; do
  "$GETH_BIN" init --datadir ./$node genesis.json
  echo "✓ $node initialized"
done

# ── 7. START ALL 9 PROCESSES NOW ─────────────────────────────────
./start-all.sh &

echo ""
echo "Waiting for genesis at $(date -d @$GENESIS_TIME)"
echo "Current time: $(date)"
echo "Seconds remaining: $(( GENESIS_TIME - $(date +%s) ))"
