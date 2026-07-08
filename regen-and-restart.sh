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

# Prepare execution genesis with required Geth fields and deposit contract bytecode
# BEFORE running prysmctl so the generated genesis.ssz matches the execution genesis.
python3 - <<'PY'
import json, os, subprocess

with open('genesis.json.working') as f:
    g = json.load(f)

c = g.setdefault('config', {})
c['chainId'] = c.get('chainId', 12345)
c['terminalTotalDifficulty'] = c.get('terminalTotalDifficulty', 0)
c['terminalTotalDifficultyPassed'] = True
c['shanghaiTime'] = 0
c['cancunTime'] = 0
c['pragueTime'] = 0
c.setdefault('blobSchedule', {
    "cancun": {"target": 3, "max": 6, "baseFeeUpdateFraction": 3338477},
    "prague": {"target": 6, "max": 9, "baseFeeUpdateFraction": 5007716}
})

DEPOSIT_ADDR = '0x4242424242424242424242424242424242424242'
if os.path.exists('DepositContract.sol'):
    r = subprocess.run(
        ['solc', '--combined-json', 'bin-runtime', 'DepositContract.sol'],
        capture_output=True, text=True
    )
    if r.returncode == 0:
        data = json.loads(r.stdout)
        contracts = data.get('contracts', {})
        key = next((k for k in contracts if k.endswith(':DepositContract')), None)
        if key:
            bytecode = contracts[key]['bin-runtime'].strip()
            alloc = g.setdefault('alloc', {})
            entry = alloc.get(DEPOSIT_ADDR, {})
            entry.setdefault('balance', '0x0')
            entry['code'] = '0x' + bytecode
            alloc[DEPOSIT_ADDR] = entry
            print(f'Injected deposit contract runtime bytecode ({len(bytecode)} hex chars) at {DEPOSIT_ADDR}')
        else:
            print('Warning: DepositContract not found in solc output')
    else:
        print('Warning: solc bin-runtime failed:', r.stderr[:200])
else:
    print('Warning: DepositContract.sol not found; deposit contract will not have bytecode')

with open('genesis.json', 'w') as f:
    json.dump(g, f, indent='\t')
PY

./prysmctl-v5.3.2 testnet generate-genesis \
  --fork=electra \
  --num-validators=$NUM_NODES \
  --genesis-time=$GENESIS_TIME \
  --chain-config-file=config.yaml \
  --geth-genesis-json-in=genesis.json \
  --geth-genesis-json-out=genesis.json \
  --output-ssz=genesis.ssz

for i in $(seq 1 $NUM_NODES); do
  ./geth --datadir "node${i}" init genesis.json
done

echo "Done. Genesis time was: $GENESIS_TIME"
