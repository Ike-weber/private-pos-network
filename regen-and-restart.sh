#!/bin/bash
set -e
cd "$(dirname "$0")"

NUM_NODES=${1:-4}
GENESIS_TIME=$(date -d "+2 minutes" +%s)
echo "Using genesis time: $GENESIS_TIME"
echo "Node count: $NUM_NODES"

# Wipe old data
for i in $(seq 1 $NUM_NODES); do
  rm -rf "beacon${i}" "validator${i}" "node${i}/geth" 2>/dev/null || true
  mkdir -p "beacon${i}" "node${i}"
done
rm -f genesis.json genesis.ssz

./prysmctl-v5.3.2 testnet generate-genesis \
  --fork=electra \
  --num-validators=$NUM_NODES \
  --genesis-time=$GENESIS_TIME \
  --chain-config-file=config.yaml \
  --geth-genesis-json-in=genesis.json.working \
  --geth-genesis-json-out=genesis.json \
  --output-ssz=genesis.ssz

# Ensure required Geth 1.17.4 fields are present
python3 - <<'PY'
import json
with open('genesis.json') as f:
    g = json.load(f)
c = g.setdefault('config', {})
c['chainId'] = c.get('chainId', 12345)
c['terminalTotalDifficulty'] = c.get('terminalTotalDifficulty', 0)
c['terminalTotalDifficultyPassed'] = True
c.setdefault('shanghaiTime', 0)
c.setdefault('cancunTime', 0)
c.setdefault('pragueTime', 0)
c.setdefault('blobSchedule', {
    "cancun": {"target": 3, "max": 6, "baseFeeUpdateFraction": 3338477},
    "prague": {"target": 6, "max": 9, "baseFeeUpdateFraction": 5007716}
})
with open('genesis.json', 'w') as f:
    json.dump(g, f, indent='\t')
PY

for i in $(seq 1 $NUM_NODES); do
  ./geth --datadir "node${i}" init genesis.json
done

echo "Done. Genesis time was: $GENESIS_TIME"
