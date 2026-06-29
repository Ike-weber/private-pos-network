#!/bin/bash
set -e

cd "$(dirname "$0")"
export USE_PRYSM_VERSION=v5.3.2

# ── 0. DOWNLOAD GETH IF MISSING ─────────────────────────────────
if [ ! -x ./geth-1.15.11 ]; then
  echo "Downloading Geth 1.15.11..."
  curl -L https://gethstore.blob.core.windows.net/builds/geth-linux-amd64-1.15.11-36b2371c.tar.gz -o geth-1.15.11.tar.gz
  tar xzf geth-1.15.11.tar.gz
  mv geth-linux-amd64-1.15.11-36b2371c/geth ./geth-1.15.11
  chmod +x geth-1.15.11
  rm -rf geth-linux-amd64-1.15.11-36b2371c geth-1.15.11.tar.gz
  echo "Geth 1.15.11 ready"
fi

# ── 1. KILL EVERYTHING ──────────────────────────────────────────
pkill -9 -f geth || true
pkill -9 -f beacon-chain || true
pkill -9 -f validator || true
sleep 3
pgrep -f "geth|beacon-chain|validator" && echo "STALE PROCESSES!" && exit 1

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
  ./geth-1.15.11 init --datadir ./$node genesis.json
  echo "✓ $node initialized"
done

# ── 7. START ALL 9 PROCESSES NOW ─────────────────────────────────
./start-all.sh &

echo ""
echo "Waiting for genesis at $(date -d @$GENESIS_TIME)"
echo "Current time: $(date)"
echo "Seconds remaining: $(( GENESIS_TIME - $(date +%s) ))"
