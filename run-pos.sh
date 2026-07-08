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

# ── 0b. ENSURE PRYSM BINARIES ARE AVAILABLE ──────────────────────
PRYSM_VERSION="v5.3.2"
if [ ! -x "./prysmctl-${PRYSM_VERSION}" ] || [ ! -x "./beacon-chain-${PRYSM_VERSION}" ] || [ ! -x "./validator-${PRYSM_VERSION}" ]; then
  echo "Downloading Prysm ${PRYSM_VERSION} binaries..."
  mkdir -p dist
  for bin in beacon-chain validator prysmctl; do
    FILE="dist/${bin}-${PRYSM_VERSION}-linux-amd64"
    if [ ! -x "$FILE" ]; then
      URL="https://github.com/OffchainLabs/prysm/releases/download/${PRYSM_VERSION}/${bin}-${PRYSM_VERSION}-linux-amd64"
      echo "  $URL"
      curl -L --fail --max-time 180 "$URL" -o "$FILE"
      chmod +x "$FILE"
    fi
    ln -sf "$FILE" "./${bin}-${PRYSM_VERSION}"
  done
  echo "Prysm ${PRYSM_VERSION} ready"
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
rm -f genesis.ssz genesis.json
mkdir -p logs
for node in node1 node2 node3; do
  rm -rf $node/geth
  mkdir -p $node/geth
done

# ── 3. SET GENESIS TIME ──────────────────────────────────────────
GENESIS_TIME=$(( $(date +%s) + 180 ))
echo "Genesis at: $GENESIS_TIME = $(date -d @$GENESIS_TIME)"

# ── 4. BUILD FINAL genesis.json FROM TEMPLATE ────────────────────
# prysmctl uses the input execution genesis to compute the genesis state root
# that goes into genesis.ssz. ANY change to genesis.json AFTER prysmctl runs
# breaks EL↔CL alignment ("unknown finalized root", "el_offline", etc.).
# So we prepare the FINAL genesis.json here, before generating genesis.ssz.
echo "Preparing final genesis.json from template..."
python3 << 'PYEOF'
import json, os, subprocess, sys

DEPOSIT_ADDR = '0x4242424242424242424242424242424242424242'

with open('genesis.json.working') as f:
    g = json.load(f)

# Normalize address keys to lowercase (Geth requirement)
alloc = {}
for k, v in g.get('alloc', {}).items():
    alloc[k.lower().replace('0x', '')] = v
g['alloc'] = alloc

# Ensure deposit contract has correct runtime bytecode from source
if os.path.exists('DepositContract.sol'):
    r = subprocess.run(
        ['solc', '--combined-json', 'bin-runtime', 'DepositContract.sol'],
        capture_output=True, text=True
    )
    if r.returncode == 0:
        data = json.loads(r.stdout)
        key = next((k for k in data.get('contracts', {}) if k.endswith(':DepositContract')), None)
        if key:
            bytecode = data['contracts'][key]['bin-runtime'].strip()
            entry = alloc.get(DEPOSIT_ADDR.lower().replace('0x', ''), {})
            entry.setdefault('balance', '0x0')
            entry['code'] = '0x' + bytecode
            alloc[DEPOSIT_ADDR.lower().replace('0x', '')] = entry
            print(f'Injected DepositContract runtime bytecode ({len(bytecode)} hex chars)')
        else:
            print('ERROR: DepositContract not found in solc output', file=sys.stderr)
            sys.exit(1)
    else:
        print('ERROR: solc failed:', r.stderr[:200], file=sys.stderr)
        sys.exit(1)
else:
    print('ERROR: DepositContract.sol not found', file=sys.stderr)
    sys.exit(1)

# Final config values
c = g.setdefault('config', {})
c['chainId'] = c.get('chainId', 12345)
c['terminalTotalDifficulty'] = 0
c['terminalTotalDifficultyPassed'] = True
# Forks active from genesis; prysmctl will align these with GENESIS_TIME
# but we keep them at 0 so they are active before the first block.
c['shanghaiTime'] = 0
c['cancunTime'] = 0
c['pragueTime'] = 0
c.setdefault('blobSchedule', {
    'cancun': {'target': 3, 'max': 6, 'baseFeeUpdateFraction': 3338477},
    'prague': {'target': 6, 'max': 9, 'baseFeeUpdateFraction': 5007716}
})

# Set execution genesis timestamp to match beacon genesis time
g['timestamp'] = hex(int(sys.argv[1])) if len(sys.argv) > 1 else '0x0'

with open('genesis.json', 'w') as f:
    json.dump(g, f, indent='\t')

print(f'Final genesis.json written with timestamp={g["timestamp"]}')
print(f'Deposit contract code present: {"code" in alloc[DEPOSIT_ADDR.lower().replace("0x", "")]}')
PYEOF "$GENESIS_TIME"

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to prepare genesis.json. Aborting."
    exit 1
fi

# ── 4b. GENERATE genesis.ssz FROM FINAL genesis.json ──────────────
# prysmctl reads genesis.json, computes the EL state root, and embeds it
# in genesis.ssz. Do NOT modify genesis.json after this step.
./prysmctl-v5.3.2 testnet generate-genesis \
  --fork electra \
  --num-validators 3 \
  --genesis-time $GENESIS_TIME \
  --chain-config-file config.yaml \
  --geth-genesis-json-in genesis.json \
  --geth-genesis-json-out genesis.json \
  --output-ssz genesis.ssz

# ── 5. VERIFY genesis.json WAS NOT CORRUPTED BY prysmctl ─────────
python3 -c "
import json
g = json.load(open('genesis.json'))
c = g.setdefault('config', {})
assert c.get('terminalTotalDifficultyPassed') == True, 'terminalTotalDifficultyPassed missing'
assert 'code' in g.get('alloc', {}).get('4242424242424242424242424242424242424242', {}), 'deposit contract code missing'
print('timestamp:', g.get('timestamp'))
print('terminalTotalDifficultyPassed:', c.get('terminalTotalDifficultyPassed'))
print('depositContractAddress:', c.get('depositContractAddress'))
print('deposit contract code present: True')
print('genesis.json verified')
"

# ── 6. INIT GETH ─────────────────────────────────────────────────
for node in node1 node2 node3; do
  "$GETH_BIN" init --datadir ./$node genesis.json
  echo "✓ $node initialized"
done

# ── 7. START ALL 9 PROCESSES NOW ─────────────────────────────────
# Use nohup so start-all.sh survives the run-pos.sh shell exiting.
nohup ./start-all.sh 3 > logs/start-all.log 2>&1 &
disown

echo ""
echo "Waiting for genesis at $(date -d @$GENESIS_TIME)"
echo "Current time: $(date)"
echo "Seconds remaining: $(( GENESIS_TIME - $(date +%s) ))"
