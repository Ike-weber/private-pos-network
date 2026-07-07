#!/bin/bash
# start-with-bootnode.sh
# Local bootnode test: one Geth node acts as the bootstrap peer for all others.
# This stays on one machine and uses 127.0.0.1.

set -e
cd "$(dirname "$0")"

NUM_NODES=${1:-3}

echo "=== Local bootnode test with $NUM_NODES Geth nodes ==="

# Wipe only node datadirs used in this test (preserve beacon/validator data)
for i in $(seq 1 $NUM_NODES); do
  rm -rf "node${i}-boottest"
  mkdir -p "node${i}-boottest"
done

# 1. Initialize all Geth datadirs with the same genesis
for i in $(seq 1 $NUM_NODES); do
  ./geth init --datadir "node${i}-boottest" genesis.json
  echo "Initialized node${i}-boottest"
done

# 2. Start node1 (the bootnode) first
nohup ./geth \
  --datadir "node1-boottest" \
  --port 30401 \
  --http --http.port 8641 --http.api eth,net,web3,engine,admin --http.addr 127.0.0.1 \
  --authrpc.addr 127.0.0.1 --authrpc.port 8661 --authrpc.jwtsecret jwt.hex \
  --syncmode full --gcmode full --state.scheme path --snapshot \
  --networkid 12345 --ipcdisable \
  --nat extip:127.0.0.1 \
  --bootnodes "" \
  >> "logs/geth1-boottest.log" 2>&1 &

echo "Bootnode (node1) starting, waiting for nodeInfo..."
sleep 5

# 3. Get node1 enode
ENODE1=$(curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"admin_nodeInfo","params":[],"id":1}' \
  http://localhost:8641 | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['enode'])")

echo "Bootnode enode: $ENODE1"

# 4. Start node2..N with bootnode set to node1
for i in $(seq 2 $NUM_NODES); do
  HTTP_PORT=$((8640 + i))
  P2P_PORT=$((30400 + i))
  AUTH_PORT=$((8660 + i))
  nohup ./geth \
    --datadir "node${i}-boottest" \
    --port $P2P_PORT \
    --http --http.port $HTTP_PORT --http.api eth,net,web3,engine,admin --http.addr 127.0.0.1 \
    --authrpc.addr 127.0.0.1 --authrpc.port $AUTH_PORT --authrpc.jwtsecret jwt.hex \
    --syncmode full --gcmode full --state.scheme path --snapshot \
    --networkid 12345 --ipcdisable \
    --nat extip:127.0.0.1 \
    --bootnodes "$ENODE1" \
    >> "logs/geth${i}-boottest.log" 2>&1 &
  echo "Started node${i} with bootnode"
done

echo "Waiting for peering..."
sleep 10

# 5. Check peer counts
for i in $(seq 1 $NUM_NODES); do
  HTTP_PORT=$((8640 + i))
  PEERS=$(curl -s -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"admin_peers","params":[],"id":1}' \
    http://localhost:${HTTP_PORT} | python3 -c "import sys,json; print(len(json.load(sys.stdin)['result']))")
  echo "node${i} peer count: $PEERS"
done

echo "=== Done. Logs: logs/geth*-boottest.log ==="
