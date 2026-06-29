#!/bin/bash
cd "$(dirname "$0")"
export USE_PRYSM_VERSION=v5.3.2
export PRYSM_ALLOW_UNVERIFIED_BINARIES=1

PRYSM_VERSION="v5.3.2"
BEACON="./beacon-chain-${PRYSM_VERSION}"
VALIDATOR="./validator-${PRYSM_VERSION}"

# Start Geth nodes
./geth-1.17.4 --datadir node1 --port 30301 --http --http.port 8541 --http.api eth,net,engine,admin --authrpc.port 8551 --authrpc.jwtsecret jwt.hex --syncmode full --networkid 12345 --ipcdisable >> logs/geth1.log 2>&1 &
./geth-1.17.4 --datadir node2 --port 30302 --http --http.port 8542 --http.api eth,net,engine,admin --authrpc.port 8552 --authrpc.jwtsecret jwt.hex --syncmode full --networkid 12345 --ipcdisable >> logs/geth2.log 2>&1 &
./geth-1.17.4 --datadir node3 --port 30303 --http --http.port 8543 --http.api eth,net,engine,admin --authrpc.port 8553 --authrpc.jwtsecret jwt.hex --syncmode full --networkid 12345 --ipcdisable >> logs/geth3.log 2>&1 &
echo "Geth started"
sleep 10

# Peer Geth via HTTP (IPC disabled)
ENODE1=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"admin_nodeInfo","params":[],"id":1}' http://localhost:8541 | python3 -c "import sys,json; e=json.load(sys.stdin)['result']['enode']; print(e.replace(e.split('@')[1].split(':')[0],'127.0.0.1'))")
ENODE2=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"admin_nodeInfo","params":[],"id":1}' http://localhost:8542 | python3 -c "import sys,json; e=json.load(sys.stdin)['result']['enode']; print(e.replace(e.split('@')[1].split(':')[0],'127.0.0.1'))")
ENODE3=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"admin_nodeInfo","params":[],"id":1}' http://localhost:8543 | python3 -c "import sys,json; e=json.load(sys.stdin)['result']['enode']; print(e.replace(e.split('@')[1].split(':')[0],'127.0.0.1'))")
curl -s -X POST -H "Content-Type: application/json" --data "{\"jsonrpc\":\"2.0\",\"method\":\"admin_addPeer\",\"params\":[\"$ENODE2\"],\"id\":1}" http://localhost:8541 >/dev/null
curl -s -X POST -H "Content-Type: application/json" --data "{\"jsonrpc\":\"2.0\",\"method\":\"admin_addPeer\",\"params\":[\"$ENODE3\"],\"id\":1}" http://localhost:8541 >/dev/null
curl -s -X POST -H "Content-Type: application/json" --data "{\"jsonrpc\":\"2.0\",\"method\":\"admin_addPeer\",\"params\":[\"$ENODE1\"],\"id\":1}" http://localhost:8542 >/dev/null
curl -s -X POST -H "Content-Type: application/json" --data "{\"jsonrpc\":\"2.0\",\"method\":\"admin_addPeer\",\"params\":[\"$ENODE3\"],\"id\":1}" http://localhost:8542 >/dev/null
curl -s -X POST -H "Content-Type: application/json" --data "{\"jsonrpc\":\"2.0\",\"method\":\"admin_addPeer\",\"params\":[\"$ENODE1\"],\"id\":1}" http://localhost:8543 >/dev/null
curl -s -X POST -H "Content-Type: application/json" --data "{\"jsonrpc\":\"2.0\",\"method\":\"admin_addPeer\",\"params\":[\"$ENODE2\"],\"id\":1}" http://localhost:8543 >/dev/null
echo "Geth peered"

# Start beacon1
$BEACON --datadir beacon1 --min-sync-peers 0 --genesis-state genesis.ssz --interop-eth1data-votes --chain-config-file config.yaml --contract-deployment-block 0 --chain-id 12345 --accept-terms-of-use --jwt-secret jwt.hex --suggested-fee-recipient 0x8B0681dBD724dcaC48b433e9df8A220D47C94a19 --execution-endpoint http://localhost:8551 --rpc-port 4000 --grpc-gateway-port 3500 --p2p-tcp-port 13000 --p2p-udp-port 12000 --bootstrap-node= >> logs/beacon1.log 2>&1 &
echo "Beacon1 started"

# Wait for beacon1 API to be ready (retry up to 30s)
for i in $(seq 1 30); do
  BEACON1_PEER=$(curl -s http://localhost:3500/eth/v1/node/identity 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data']['peer_id'])" 2>/dev/null) || true
  if [ -n "$BEACON1_PEER" ]; then
    echo "Beacon1 peer: $BEACON1_PEER"
    break
  fi
  sleep 1
done
if [ -z "$BEACON1_PEER" ]; then
  echo "ERROR: Could not get beacon1 peer ID"
  exit 1
fi

# Start beacon2/3 with correct bootstrap
$BEACON --datadir beacon2 --min-sync-peers 0 --genesis-state genesis.ssz --interop-eth1data-votes --chain-config-file config.yaml --contract-deployment-block 0 --chain-id 12345 --accept-terms-of-use --jwt-secret jwt.hex --suggested-fee-recipient 0xC4d87b80780117F805D620c4FF88e5380699dB41 --execution-endpoint http://localhost:8552 --rpc-port 4001 --grpc-gateway-port 3501 --p2p-tcp-port 13001 --p2p-udp-port 12001 --bootstrap-node=/ip4/127.0.0.1/tcp/13000/p2p/$BEACON1_PEER >> logs/beacon2.log 2>&1 &
$BEACON --datadir beacon3 --min-sync-peers 0 --genesis-state genesis.ssz --interop-eth1data-votes --chain-config-file config.yaml --contract-deployment-block 0 --chain-id 12345 --accept-terms-of-use --jwt-secret jwt.hex --suggested-fee-recipient 0x2F54526037527688d3b2DEFA3a0B1F4CAf78dB8F --execution-endpoint http://localhost:8553 --rpc-port 4002 --grpc-gateway-port 3502 --p2p-tcp-port 13002 --p2p-udp-port 12002 --bootstrap-node=/ip4/127.0.0.1/tcp/13000/p2p/$BEACON1_PEER >> logs/beacon3.log 2>&1 &
echo "Beacon2/3 started"
sleep 10

# Start validators
$VALIDATOR --datadir beacon1/validator --accept-terms-of-use --chain-config-file config.yaml --interop-num-validators 1 --interop-start-index 0 --beacon-rest-api-provider http://localhost:3500 >> logs/validator1.log 2>&1 &
$VALIDATOR --datadir beacon2/validator --accept-terms-of-use --chain-config-file config.yaml --interop-num-validators 1 --interop-start-index 1 --beacon-rest-api-provider http://localhost:3501 >> logs/validator2.log 2>&1 &
$VALIDATOR --datadir beacon3/validator --accept-terms-of-use --chain-config-file config.yaml --interop-num-validators 1 --interop-start-index 2 --beacon-rest-api-provider http://localhost:3502 >> logs/validator3.log 2>&1 &

echo "All started"
ps aux | grep -E "geth|prysm|beacon|validator" | grep -v grep | wc -l
