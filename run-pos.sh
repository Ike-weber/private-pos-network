#!/bin/bash
set -e

# ── 1. KILL EVERYTHING ──────────────────────────────────────────
pkill -9 -f geth || true
pkill -9 -f beacon-chain || true
pkill -9 -f validator || true
sleep 3
# Confirm nothing left
pgrep -f "geth|beacon-chain|validator" && echo "STALE PROCESSES!" && exit 1

# ── 2. WIPE ALL DATA (complete, not partial) ─────────────────────
rm -rf beacon1/* beacon2/* beacon3/*
rm -rf validator1/* validator2/* validator3/*
for node in node1 node2 node3; do
  rm -rf $node/geth/chaindata $node/geth/lightchaindata $node/geth/triecache
  rm -rf $node/geth
  mkdir -p $node/geth
done

# Verify beacon dirs are clean before proceeding
for dir in beacon1 beacon2 beacon3; do
  if find $dir -name "genesis-*.ssz" 2>/dev/null | grep -q .; then
    echo "ERROR: cached genesis still in $dir — aborting"
    exit 1
  fi
done
echo "✓ All beacon dirs clean"

# ── 3. BUILD CORRECT genesis.json FIRST (template, never touched by prysmctl) ──
# Start from your known-good template
cp genesis.json.working genesis_template.json

# Ensure all required fields are present
python3 -c "
import json
g = json.load(open('genesis_template.json'))
g['config']['terminalTotalDifficultyPassed'] = True
g['config']['terminalTotalDifficulty'] = 0
g['config']['blobSchedule'] = {
    'cancun': {'target': 3, 'max': 6, 'baseFeeUpdateFraction': 3338477},
    'prague':  {'target': 6, 'max': 9, 'baseFeeUpdateFraction': 5007716},
    'osaka':   {'target': 6, 'max': 9, 'baseFeeUpdateFraction': 5007716}
}
json.dump(g, open('genesis_template.json', 'w'), indent=2)
print('Template ready')
"

# ── 4. SET GENESIS TIME ──────────────────────────────────────────
GENESIS_TIME=$(( $(date +%s) + 180 ))   # 3 minutes from now
echo "Genesis at: $GENESIS_TIME = $(date -d @$GENESIS_TIME)"

# ── 5. GENERATE genesis.ssz (prysmctl writes to genesis.json, not template) ──
./prysmctl testnet generate-genesis \
  --fork fulu \
  --num-validators 64 \
  --genesis-time $GENESIS_TIME \
  --chain-config-file config.yaml \
  --geth-genesis-json-in genesis_template.json \
  --geth-genesis-json-out genesis.json \
  --output-ssz genesis.ssz

# ── 6. FIX genesis.json AFTER prysmctl (it strips fields) ────────
python3 -c "
import json
g = json.load(open('genesis.json'))
g['config']['terminalTotalDifficultyPassed'] = True
g['config']['terminalTotalDifficulty'] = 0
g['config']['blobSchedule'] = {
    'cancun': {'target': 3, 'max': 6, 'baseFeeUpdateFraction': 3338477},
    'prague':  {'target': 6, 'max': 9, 'baseFeeUpdateFraction': 5007716},
    'osaka':   {'target': 6, 'max': 9, 'baseFeeUpdateFraction': 5007716}
}
# Verify timestamp
print('timestamp:', g.get('timestamp'))
print('terminalTotalDifficultyPassed:', g['config'].get('terminalTotalDifficultyPassed'))
print('blobSchedule:', list(g['config'].get('blobSchedule', {}).keys()))
json.dump(g, open('genesis.json', 'w'), indent=2)
print('genesis.json fixed')
"

# ── 7. INIT GETH ─────────────────────────────────────────────────
for node in node1 node2 node3; do
  geth init --datadir ./$node genesis.json
  echo "✓ $node initialized"
done

# ── 8. START ALL 9 PROCESSES NOW (genesis still ~3 min away) ─────
./start-all.sh &   # or however you start them

echo ""
echo "Waiting for genesis at $(date -d @$GENESIS_TIME)"
echo "Current time: $(date)"
echo "Seconds remaining: $(( GENESIS_TIME - $(date +%s) ))"
