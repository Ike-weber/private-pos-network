#!/bin/bash
set -e

cd "$(dirname "$0")"
export USE_PRYSM_VERSION=v5.3.2
# Allow Prysm to fall back to unverified binaries if signatures/checksums are unavailable
export PRYSM_ALLOW_UNVERIFIED_BINARIES=1

JWT_SECRET_PATH="${JWT_SECRET_PATH:-/home/harsh/.eth-pos/secrets/private-pos-jwt.hex}"
if [ ! -f "$JWT_SECRET_PATH" ]; then
  echo "ERROR: JWT secret not found at $JWT_SECRET_PATH"
  exit 1
fi

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

NUM_NODES=9

# ── 2. WIPE ALL DATA ────────────────────────────────────────────
for i in $(seq 1 $NUM_NODES); do
  rm -rf beacon${i}/*
  rm -rf validator${i}/*
  rm -rf node${i}/geth
  mkdir -p node${i}/geth
done
rm -f genesis.ssz genesis.json
mkdir -p logs

# ── 3. SET GENESIS TIME ──────────────────────────────────────────
GENESIS_TIME=$(( $(date +%s) + 180 ))
echo "Genesis at: $GENESIS_TIME = $(date -d @$GENESIS_TIME)"

# ── 4. PATCH DEPOSIT CONTRACT BYTECODE IN TEMPLATE ───────────────
# prysmctl emits the deposit contract as init+runtime concatenated.
# Geth expects only the runtime bytecode. Strip the init prefix from the
# template so prysmctl generates a consistent genesis.json and genesis.ssz.
echo "Patching deposit contract bytecode..."
python3 << 'PYEOF'
import json, sys

RUNTIME_START = 0x137
RUNTIME_LEN   = 0x17bd
CONTRACT      = "4242424242424242424242424242424242424242"

for fname in ["genesis_with_deposit.json", "genesis.json"]:
    try:
        with open(fname, 'r') as f:
            genesis = json.load(f)
    except FileNotFoundError:
        continue

    code_hex   = genesis['alloc'][CONTRACT]['code']
    code_bytes = bytes.fromhex(code_hex[2:] if code_hex.startswith('0x') else code_hex)

    # Only patch if still contains init code (length > runtime-only)
    if len(code_bytes) <= RUNTIME_LEN:
        print(f"✓ {fname}: already runtime-only ({len(code_bytes)} bytes), skipping")
        continue

    runtime = code_bytes[RUNTIME_START : RUNTIME_START + RUNTIME_LEN]

    if runtime[:4].hex() != '60806040':
        print(f"ERROR: {fname}: unexpected runtime start {runtime[:4].hex()}", file=sys.stderr)
        sys.exit(1)

    genesis['alloc'][CONTRACT]['code'] = '0x' + runtime.hex()

    with open(fname, 'w') as f:
        json.dump(genesis, f, indent=2)

    print(f"✓ {fname}: patched to runtime-only ({len(runtime)} bytes)")
PYEOF

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to patch deposit contract bytecode. Aborting."
    exit 1
fi

# ── 4b. GENERATE genesis.ssz ──────────────────────────────────────
# Use the template that includes the real deposit contract bytecode at
# 0x4242424242424242424242424242424242424242
# Use node1's real deposit as the single bootstrap validator so the chain starts
# producing blocks immediately. The other 8 validators are imported via keystores
# and funded with on-chain deposits after startup.
./prysmctl-v5.3.2 testnet generate-genesis \
  --fork electra \
  --num-validators 0 \
  --deposit-json-file deposit_data_9/deposit_data_bootstrap.json \
  --genesis-time $GENESIS_TIME \
  --chain-config-file config.yaml \
  --geth-genesis-json-in genesis_with_deposit.json \
  --geth-genesis-json-out genesis.json \
  --output-ssz genesis.ssz

# ── 5. FIX genesis.json AFTER prysmctl ───────────────────────────
python3 -c "
import json
g = json.load(open('genesis.json'))
c = g.setdefault('config', {})
c['terminalTotalDifficultyPassed'] = True
c['terminalTotalDifficulty'] = 0
c.setdefault('shanghaiTime', 0)
c.setdefault('cancunTime', 0)
c.setdefault('pragueTime', 0)
c.setdefault('blobSchedule', {
  'cancun': {'target': 3, 'max': 6, 'baseFeeUpdateFraction': 3338477},
  'prague': {'target': 6, 'max': 9, 'baseFeeUpdateFraction': 5007716}
})
print('timestamp:', g.get('timestamp'))
print('terminalTotalDifficultyPassed:', c.get('terminalTotalDifficultyPassed'))
print('depositContractAddress:', c.get('depositContractAddress'))
print('deposit contract code present:', 'code' in g.get('alloc', {}).get('4242424242424242424242424242424242424242', {}))
json.dump(g, open('genesis.json', 'w'), indent=2)
print('genesis.json fixed')
"

# ── 6. INIT GETH ─────────────────────────────────────────────────
for i in $(seq 1 $NUM_NODES); do
  "$GETH_BIN" init --datadir ./node${i} genesis.json
  echo "✓ node${i} initialized"
done

# ── 7. START ALL PROCESSES NOW ─────────────────────────────────
# Use nohup so start-all.sh survives the run-pos.sh shell exiting.
nohup JWT_SECRET_PATH="$JWT_SECRET_PATH" ./start-all.sh $NUM_NODES > logs/start-all.log 2>&1 &
disown

echo ""
echo "Waiting for genesis at $(date -d @$GENESIS_TIME)"
echo "Current time: $(date)"
echo "Seconds remaining: $(( GENESIS_TIME - $(date +%s) ))"
