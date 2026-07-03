#!/bin/bash
set -e
cd "$(dirname "$0")"

# Set these per machine before running:
# export NODE_ID=1
# export MACHINE_IP=10.0.0.1
# export SEED_BEACON_IP=10.0.0.1
# export SEED_BEACON_P2P_PORT=13000
# export SEED_BEACON_PEER_ID=16Uiu2HAk... (only needed for nodes 2-9)

NODE_ID=${NODE_ID:-1}
MACHINE_IP=${MACHINE_IP:-127.0.0.1}
SEED_BEACON_IP=${SEED_BEACON_IP:-$MACHINE_IP}

PRYSM_VERSION="v5.3.2"
BEACON="./beacon-chain-${PRYSM_VERSION}"
VALIDATOR="./validator-${PRYSM_VERSION}"
GETH="./geth-1.17.4"

mkdir -p logs

# Suggested fee recipients per node (index 0 = node 1). Falls back to a default address if NODE_ID is beyond the list.
FEE_RECIPIENTS=(
  "0x8B0681dBD724dcaC48b433e9df8A220D47C94a19"
  "0xC4d87b80780117F805D620c4FF88e5380699dB41"
  "0x2F54526037527688d3b2DEFA3a0B1F4CAf78dB8F"
  "0x1234567890123456789012345678901234567890"
  "0xabcdefabcdefabcdefabcdefabcdefabcdefabcd"
  "0x1111111111111111111111111111111111111111"
  "0x2222222222222222222222222222222222222222"
  "0x3333333333333333333333333333333333333333"
  "0x4444444444444444444444444444444444444444"
)
if [ "$NODE_ID" -le "${#FEE_RECIPIENTS[@]}" ]; then
  FEE_RECIP=${FEE_RECIPIENTS[$((NODE_ID-1))]}
else
  FEE_RECIP="0xDeaDbeefdEAdbeefdEadbEEFdeadbeefDeAdbeEf"
fi

# Ports for this machine
GETH_HTTP_PORT=$((8540 + NODE_ID))
GETH_AUTH_PORT=$((8550 + NODE_ID))
GETH_P2P_PORT=$((30300 + NODE_ID))
BEACON_RPC_PORT=$((3999 + NODE_ID))
BEACON_GATEWAY_PORT=$((3499 + NODE_ID))
BEACON_TCP_PORT=$((12999 + NODE_ID))
BEACON_UDP_PORT=$((11999 + NODE_ID))

echo "Starting node $NODE_ID on $MACHINE_IP"

# Initialize Geth if needed
if [ ! -d "node1/geth" ]; then
  $GETH --datadir node1 init genesis.json
fi

# Start Geth
$GETH --datadir node1 \
  --port $GETH_P2P_PORT \
  --http --http.addr 0.0.0.0 --http.port $GETH_HTTP_PORT --http.api eth,net,engine,admin \
  --authrpc.addr 0.0.0.0 --authrpc.port $GETH_AUTH_PORT --authrpc.vhosts "*" --authrpc.jwtsecret jwt.hex \
  --syncmode full --networkid 12345 --ipcdisable \
  >> logs/geth.log 2>&1 &

echo "Geth started on port $GETH_HTTP_PORT"
sleep 5

# Start Prysm beacon
if [ "$NODE_ID" = "1" ]; then
  # Seed node: no static peers, waits for others to connect
  $BEACON --datadir beacon1 \
    --min-sync-peers 0 \
    --genesis-state genesis.ssz \
    --interop-eth1data-votes \
    --chain-config-file config.yaml \
    --contract-deployment-block 0 --chain-id 12345 \
    --accept-terms-of-use --jwt-secret jwt.hex \
    --suggested-fee-recipient $FEE_RECIP \
    --execution-endpoint http://localhost:$GETH_AUTH_PORT \
    --rpc-host 0.0.0.0 --rpc-port $BEACON_RPC_PORT \
    --grpc-gateway-host 0.0.0.0 --grpc-gateway-port $BEACON_GATEWAY_PORT \
    --p2p-tcp-port $BEACON_TCP_PORT --p2p-udp-port $BEACON_UDP_PORT \
    --p2p-host-ip $MACHINE_IP --bootstrap-node= \
    >> logs/beacon.log 2>&1 &
else
  # Other nodes: connect to seed beacon
  STATIC_PEER="/ip4/$SEED_BEACON_IP/tcp/$SEED_BEACON_P2P_PORT/p2p/$SEED_BEACON_PEER_ID"
  $BEACON --datadir beacon1 \
    --min-sync-peers 0 \
    --genesis-state genesis.ssz \
    --interop-eth1data-votes \
    --chain-config-file config.yaml \
    --contract-deployment-block 0 --chain-id 12345 \
    --accept-terms-of-use --jwt-secret jwt.hex \
    --suggested-fee-recipient $FEE_RECIP \
    --execution-endpoint http://localhost:$GETH_AUTH_PORT \
    --rpc-host 0.0.0.0 --rpc-port $BEACON_RPC_PORT \
    --grpc-gateway-host 0.0.0.0 --grpc-gateway-port $BEACON_GATEWAY_PORT \
    --p2p-tcp-port $BEACON_TCP_PORT --p2p-udp-port $BEACON_UDP_PORT \
    --p2p-host-ip $MACHINE_IP --peer=$STATIC_PEER \
    >> logs/beacon.log 2>&1 &
fi

echo "Beacon started on port $BEACON_GATEWAY_PORT"
sleep 10

# Start Prysm validator
$VALIDATOR --datadir beacon1/validator \
  --accept-terms-of-use --chain-config-file config.yaml \
  --interop-num-validators 1 --interop-start-index $((NODE_ID-1)) \
  --beacon-rest-api-provider http://localhost:$BEACON_GATEWAY_PORT \
  >> logs/validator.log 2>&1 &

echo "Validator started for index $((NODE_ID-1))"
echo "Node $NODE_ID is running."
