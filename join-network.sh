#!/bin/bash
set -e

cd "$(dirname "$0")"

# ── Load participant config ─────────────────────────────────────────
if [ ! -f "node-config.env" ]; then
  echo "ERROR: node-config.env not found."
  echo "Copy the example file and fill it in:"
  echo "  cp node-config.example.env node-config.env"
  echo "  nano node-config.env"
  exit 1
fi

set -a
source ./node-config.env
set +a

# ── Defaults ────────────────────────────────────────────────────────
NODE_ID="${NODE_ID:-1}"
MACHINE_IP="${MACHINE_IP:-127.0.0.1}"
BOOTNODE_IP="${BOOTNODE_IP:-$MACHINE_IP}"
BOOTNODE_P2P_PORT="${BOOTNODE_P2P_PORT:-13000}"
KEYSTORE_DIR="${KEYSTORE_DIR:-./keystore}"
JWT_SECRET_PATH="${JWT_SECRET_PATH:-./jwt-secret}"
FEE_RECIPIENT="${FEE_RECIPIENT:-0xDeaDbeefdEAdbeefdEadbEEFdeadbeefDeAdbeEf}"

PRYSM_VERSION="${PRYSM_VERSION:-v7.1.6}"
GETH_VERSION="${GETH_VERSION:-1.17.4}"

BEACON="./beacon-chain-${PRYSM_VERSION}"
VALIDATOR="./validator-${PRYSM_VERSION}"
GETH="./geth-${GETH_VERSION}"

# ── OS detection ────────────────────────────────────────────────────
OS=$(uname -s)
case "$OS" in
  Linux*)     PLATFORM="Linux" ;;
  Darwin*)    PLATFORM="Mac" ;;
  CYGWIN*|MINGW*|MSYS*) PLATFORM="Windows" ;;
  *)          PLATFORM="Unknown" ;;
esac

echo "Detected OS: $PLATFORM"

if [ "$PLATFORM" = "Unknown" ]; then
  echo "ERROR: This script only supports Windows (WSL), Mac, and Linux."
  exit 1
fi

# ── Validate required files ────────────────────────────────────────
if [ ! -f "genesis.json" ]; then
  echo "ERROR: genesis.json not found. Ask the network owner for it."
  exit 1
fi

if [ ! -f "genesis.ssz" ]; then
  echo "ERROR: genesis.ssz not found. Ask the network owner for it."
  exit 1
fi

if [ ! -f "config.yaml" ]; then
  echo "ERROR: config.yaml not found. Ask the network owner for it."
  exit 1
fi

if [ ! -f "$JWT_SECRET_PATH" ]; then
  echo "ERROR: JWT secret not found at $JWT_SECRET_PATH"
  exit 1
fi

if [ ! -d "$KEYSTORE_DIR" ]; then
  echo "ERROR: Keystore directory not found at $KEYSTORE_DIR"
  exit 1
fi

if [ ! -x "$GETH" ]; then
  echo "ERROR: Geth binary not found at $GETH"
  echo "Run: ./download-binaries.sh"
  exit 1
fi

if [ ! -x "$BEACON" ]; then
  echo "ERROR: Prysm beacon binary not found at $BEACON"
  echo "Run: ./download-binaries.sh"
  exit 1
fi

if [ ! -x "$VALIDATOR" ]; then
  echo "ERROR: Prysm validator binary not found at $VALIDATOR"
  echo "Run: ./download-binaries.sh"
  exit 1
fi

# ── Ports based on NODE_ID ────────────────────────────────────────
GETH_HTTP_PORT=$((8540 + NODE_ID))
GETH_AUTH_PORT=$((8550 + NODE_ID))
GETH_P2P_PORT=$((30300 + NODE_ID))
BEACON_RPC_PORT=$((3999 + NODE_ID))
BEACON_GATEWAY_PORT=$((3499 + NODE_ID))
BEACON_TCP_PORT=$((12999 + NODE_ID))
BEACON_UDP_PORT=$((11999 + NODE_ID))

# ── Prepare logs and datadirs ─────────────────────────────────────
mkdir -p logs
mkdir -p "node${NODE_ID}"
mkdir -p "beacon${NODE_ID}"
mkdir -p "beacon${NODE_ID}/validator"

# ── Stop existing processes cleanly ─────────────────────────────────
echo "Stopping any existing local devnet processes..."
./stop-all.sh >/dev/null 2>&1 || true
sleep 2

# ── Initialize Geth ─────────────────────────────────────────────────
if [ ! -d "node${NODE_ID}/geth" ]; then
  echo "Initializing Geth with genesis.json..."
  "$GETH" init --datadir "node${NODE_ID}" genesis.json
else
  echo "Geth datadir already initialized."
fi

# ── Import validator keystore ──────────────────────────────────────
WALLET_DIR="beacon${NODE_ID}/validator/wallet"
rm -rf "$WALLET_DIR"
mkdir -p "$WALLET_DIR"

# Detect keystore password file
PASSWORD_FILE=""
if [ -f "${KEYSTORE_DIR}/password.txt" ]; then
  PASSWORD_FILE="${KEYSTORE_DIR}/password.txt"
elif [ -f "./keystore-password.txt" ]; then
  PASSWORD_FILE="./keystore-password.txt"
fi

if [ -n "$PASSWORD_FILE" ]; then
  echo "Importing validator keystore from $KEYSTORE_DIR..."
  "$VALIDATOR" accounts import \
    --keys-dir "$KEYSTORE_DIR" \
    --wallet-dir "$WALLET_DIR" \
    --wallet-password-file "$PASSWORD_FILE" \
    --account-password-file "$PASSWORD_FILE" \
    --accept-terms-of-use \
    >> "logs/validator-import.log" 2>&1
else
  echo "WARNING: No keystore password file found. Trying default password 'password'."
  echo "password" > /tmp/default-keystore-password.txt
  "$VALIDATOR" accounts import \
    --keys-dir "$KEYSTORE_DIR" \
    --wallet-dir "$WALLET_DIR" \
    --wallet-password-file /tmp/default-keystore-password.txt \
    --account-password-file /tmp/default-keystore-password.txt \
    --accept-terms-of-use \
    >> "logs/validator-import.log" 2>&1
fi

echo "Keystore imported into $WALLET_DIR"

# ── Start Geth ──────────────────────────────────────────────────────
echo "Starting Geth on HTTP port $GETH_HTTP_PORT..."

nohup "$GETH" --datadir "node${NODE_ID}" \
  --port "$GETH_P2P_PORT" \
  --http --http.addr 0.0.0.0 --http.port "$GETH_HTTP_PORT" --http.api eth,net,engine,admin \
  --authrpc.addr 127.0.0.1 --authrpc.port "$GETH_AUTH_PORT" --authrpc.vhosts "*" --authrpc.jwtsecret "$JWT_SECRET_PATH" \
  --syncmode full --networkid 12345 --ipcdisable \
  >> "logs/geth.log" 2>&1 &

GETH_PID=$!

# Wait for Geth RPC to be ready
echo "Waiting for Geth RPC..."
for i in $(seq 1 30); do
  if curl -s -X POST -H "Content-Type: application/json" \
      --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
      "http://localhost:${GETH_HTTP_PORT}" >/dev/null 2>&1; then
    echo "Geth ready"
    break
  fi
  sleep 1
done

# ── Start Prysm beacon ──────────────────────────────────────────────
if [ "$NODE_ID" = "1" ]; then
  echo "Starting beacon node as bootnode..."
  nohup "$BEACON" --datadir "beacon${NODE_ID}" \
    --min-sync-peers 0 \
    --genesis-state genesis.ssz \
    --chain-config-file config.yaml \
    --contract-deployment-block 0 --chain-id 12345 \
    --accept-terms-of-use --jwt-secret "$JWT_SECRET_PATH" \
    --suggested-fee-recipient "$FEE_RECIPIENT" \
    --execution-endpoint "http://localhost:${GETH_AUTH_PORT}" \
    --rpc-host 0.0.0.0 --rpc-port "$BEACON_RPC_PORT" \
    --grpc-gateway-host 0.0.0.0 --grpc-gateway-port "$BEACON_GATEWAY_PORT" \
    --p2p-tcp-port "$BEACON_TCP_PORT" --p2p-udp-port "$BEACON_UDP_PORT" \
    --p2p-host-ip "$MACHINE_IP" --bootstrap-node= \
    >> "logs/beacon.log" 2>&1 &
else
  echo "Starting beacon node and connecting to bootnode at ${BOOTNODE_IP}:${BOOTNODE_P2P_PORT}..."
  STATIC_PEER="/ip4/${BOOTNODE_IP}/tcp/${BOOTNODE_P2P_PORT}/p2p/${BOOTNODE_PEER_ID}"
  nohup "$BEACON" --datadir "beacon${NODE_ID}" \
    --min-sync-peers 0 \
    --genesis-state genesis.ssz \
    --chain-config-file config.yaml \
    --contract-deployment-block 0 --chain-id 12345 \
    --accept-terms-of-use --jwt-secret "$JWT_SECRET_PATH" \
    --suggested-fee-recipient "$FEE_RECIPIENT" \
    --execution-endpoint "http://localhost:${GETH_AUTH_PORT}" \
    --rpc-host 0.0.0.0 --rpc-port "$BEACON_RPC_PORT" \
    --grpc-gateway-host 0.0.0.0 --grpc-gateway-port "$BEACON_GATEWAY_PORT" \
    --p2p-tcp-port "$BEACON_TCP_PORT" --p2p-udp-port "$BEACON_UDP_PORT" \
    --p2p-host-ip "$MACHINE_IP" --peer="$STATIC_PEER" \
    >> "logs/beacon.log" 2>&1 &
fi

BEACON_PID=$!

echo "Waiting for beacon node API..."
for i in $(seq 1 30); do
  if curl -s "http://localhost:${BEACON_GATEWAY_PORT}/eth/v1/node/health" >/dev/null 2>&1; then
    echo "Beacon node ready"
    break
  fi
  sleep 1
done

# ── Start Prysm validator ────────────────────────────────────────────
echo "Starting validator..."

nohup "$VALIDATOR" --datadir "beacon${NODE_ID}/validator" \
  --wallet-dir "$WALLET_DIR" \
  --wallet-password-file "$PASSWORD_FILE" \
  --beacon-rest-api-provider "http://localhost:${BEACON_GATEWAY_PORT}" \
  --accept-terms-of-use \
  --chain-config-file config.yaml \
  >> "logs/validator.log" 2>&1 &

VALIDATOR_PID=$!

# ── Summary ─────────────────────────────────────────────────────────
echo ""
echo "========================================"
echo "Node $NODE_ID is running on $PLATFORM"
echo "Geth HTTP:    http://localhost:${GETH_HTTP_PORT}"
echo "Beacon REST:  http://localhost:${BEACON_GATEWAY_PORT}"
echo "Geth log:     logs/geth.log"
echo "Beacon log:   logs/beacon.log"
echo "Validator log: logs/validator.log"
echo "========================================"
echo ""
echo "Press Ctrl+C to stop."

# ── Wait for interrupt, then stop ───────────────────────────────────
cleanup() {
  echo ""
  echo "Stopping node $NODE_ID..."
  kill "$VALIDATOR_PID" "$BEACON_PID" "$GETH_PID" 2>/dev/null || true
  sleep 2
  kill -9 "$VALIDATOR_PID" "$BEACON_PID" "$GETH_PID" 2>/dev/null || true
  echo "Stopped."
  exit 0
}

trap cleanup INT TERM

wait
