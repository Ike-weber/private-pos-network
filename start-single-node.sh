#!/bin/bash
set -e
cd "$(dirname "$0")"
export USE_PRYSM_VERSION=v5.3.2
export PRYSM_ALLOW_UNVERIFIED_BINARIES=1

PRYSM_VERSION="v5.3.2"
BEACON="./beacon-chain-${PRYSM_VERSION}"
VALIDATOR="./validator-${PRYSM_VERSION}"

mkdir -p logs

FEE_RECIPIENT="0x8B0681dBD724dcaC48b433e9df8A220D47C94a19"

# Start Geth
HTTP_PORT=8541
AUTH_PORT=8551
P2P_PORT=30301
./geth --datadir node1 --port $P2P_PORT --http --http.port $HTTP_PORT --http.api eth,net,engine,admin --authrpc.port $AUTH_PORT --authrpc.jwtsecret jwt.hex --syncmode full --networkid 12345 --ipcdisable >> "logs/geth1.log" 2>&1 &
echo "Geth started"
sleep 10

# Resolve WSL host IP
HOST_IP=$(hostname -I | awk '{print $1}')
echo "Host IP: $HOST_IP"

# Start beacon1
mkdir -p beacon1
$BEACON --datadir beacon1 --min-sync-peers 0 --genesis-state genesis.ssz --interop-eth1data-votes --chain-config-file config.yaml --contract-deployment-block 0 --chain-id 12345 --accept-terms-of-use --jwt-secret jwt.hex --suggested-fee-recipient $FEE_RECIPIENT --execution-endpoint http://localhost:${AUTH_PORT} --rpc-port 4000 --grpc-gateway-port 3500 --p2p-tcp-port 13000 --p2p-udp-port 12000 --p2p-host-ip $HOST_IP --bootstrap-node= >> logs/beacon1.log 2>&1 &
echo "Beacon1 started"

# Wait for beacon1 API
for i in $(seq 1 30); do
  BEACON1_PEER=$(curl -s http://localhost:3500/eth/v1/node/identity 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data']['peer_id'])" 2>/dev/null) || true
  if [ -n "$BEACON1_PEER" ]; then
    echo "Beacon1 peer: $BEACON1_PEER"
    break
  fi
  sleep 1
done

sleep 10

# Start validator
mkdir -p beacon1/validator
$VALIDATOR --datadir "beacon1/validator" --accept-terms-of-use --chain-config-file config.yaml --interop-num-validators 1 --interop-start-index 0 --beacon-rest-api-provider http://localhost:3500 >> "logs/validator1.log" 2>&1 &
echo "Validator started"

echo "Single-node devnet started"
ps aux | grep -E "geth|prysm|beacon|validator" | grep -v grep | wc -l
