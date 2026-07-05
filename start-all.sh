#!/bin/bash
cd "$(dirname "$0")"
export USE_PRYSM_VERSION=v5.3.2
export PRYSM_ALLOW_UNVERIFIED_BINARIES=1

PRYSM_VERSION="v5.3.2"
BEACON="./beacon-chain-${PRYSM_VERSION}"
VALIDATOR="./validator-${PRYSM_VERSION}"
NUM_NODES=${1:-4}

mkdir -p logs

# Suggested fee recipients for each node
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

# Resolve WSL host IP dynamically (first non-loopback IPv4)
HOST_IP=$(hostname -I | awk '{print $1}')
if [ -z "$HOST_IP" ]; then
  echo "ERROR: Could not resolve HOST_IP"
  exit 1
fi
echo "Host IP: $HOST_IP"

# Start Geth nodes with full execution-layer features enabled
for i in $(seq 1 $NUM_NODES); do
  HTTP_PORT=$((8540 + i))
  WS_PORT=$((8550 + i))
  AUTH_PORT=$((8560 + i))
  METRICS_PORT=$((6060 + i))
  P2P_PORT=$((30300 + i))
  nohup ./geth \
    --datadir "node${i}" \
    --port $P2P_PORT \
    --http --http.port $HTTP_PORT --http.api eth,net,web3,engine,admin,debug,txpool,clique --http.vhosts '*' --http.corsdomain '*' --http.addr 127.0.0.1 \
    --ws --ws.port $WS_PORT --ws.api eth,net,web3,engine,admin,debug,txpool --ws.origins '*' \
    --authrpc.addr 127.0.0.1 --authrpc.port $AUTH_PORT --authrpc.vhosts localhost --authrpc.jwtsecret jwt.hex \
    --metrics --metrics.addr 127.0.0.1 --metrics.port $METRICS_PORT \
    --syncmode full --gcmode archive --state.scheme path --snapshot \
    --networkid 12345 --ipcdisable \
    --nat extip:$HOST_IP --netrestrict 172.25.235.0/24 \
    >> "logs/geth${i}.log" 2>&1 &
done
echo "Geth started"
sleep 10

# Peer Geth nodes via HTTP (IPC disabled)
ENODES=()
for i in $(seq 1 $NUM_NODES); do
  HTTP_PORT=$((8540 + i))
  ENODE=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"admin_nodeInfo","params":[],"id":1}' "http://localhost:${HTTP_PORT}" | python3 -c "import sys,json; e=json.load(sys.stdin)['result']['enode']; print(e.replace(e.split('@')[1].split(':')[0],'127.0.0.1'))")
  ENODES+=("$ENODE")
done

for i in $(seq 1 $NUM_NODES); do
  HTTP_PORT=$((8540 + i))
  for j in $(seq 1 $NUM_NODES); do
    if [ "$i" != "$j" ]; then
      curl -s -X POST -H "Content-Type: application/json" --data "{\"jsonrpc\":\"2.0\",\"method\":\"admin_addPeer\",\"params\":[\"${ENODES[$((j-1))]}\"],\"id\":1}" "http://localhost:${HTTP_PORT}" >/dev/null
    fi
  done
done
echo "Geth peered"

# Start beacon1
nohup $BEACON --datadir beacon1 --min-sync-peers 0 --genesis-state genesis.ssz --interop-eth1data-votes --chain-config-file config.yaml --contract-deployment-block 0 --chain-id 12345 --accept-terms-of-use --jwt-secret jwt.hex --suggested-fee-recipient ${FEE_RECIPIENTS[0]} --execution-endpoint http://localhost:8561 --rpc-port 4000 --grpc-gateway-port 3500 --p2p-tcp-port 13000 --p2p-udp-port 12000 --p2p-host-ip $HOST_IP --bootstrap-node= >> logs/beacon1.log 2>&1 &
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

# Start beacon2..N with static peer to beacon1
for i in $(seq 2 $NUM_NODES); do
  HTTP_PORT=$((8540 + i))
  AUTH_PORT=$((8560 + i))
  RPC_PORT=$((3999 + i))
  GATEWAY_PORT=$((3499 + i))
  TCP_PORT=$((12999 + i))
  UDP_PORT=$((11999 + i))
  nohup $BEACON --datadir "beacon${i}" --min-sync-peers 0 --genesis-state genesis.ssz --interop-eth1data-votes --chain-config-file config.yaml --contract-deployment-block 0 --chain-id 12345 --accept-terms-of-use --jwt-secret jwt.hex --suggested-fee-recipient ${FEE_RECIPIENTS[$((i-1))]} --execution-endpoint http://localhost:${AUTH_PORT} --rpc-port ${RPC_PORT} --grpc-gateway-port ${GATEWAY_PORT} --p2p-tcp-port ${TCP_PORT} --p2p-udp-port ${UDP_PORT} --p2p-host-ip $HOST_IP --peer=/ip4/$HOST_IP/tcp/13000/p2p/$BEACON1_PEER >> "logs/beacon${i}.log" 2>&1 &
done
echo "Beacon2..${NUM_NODES} started"
sleep 10

# Start validators
for i in $(seq 1 $NUM_NODES); do
  GATEWAY_PORT=$((3499 + i))
  nohup ./validator-v5.3.2 --datadir "beacon${i}/validator" --accept-terms-of-use --chain-config-file config.yaml --interop-num-validators 1 --interop-start-index $((i-1)) --beacon-rest-api-provider http://localhost:${GATEWAY_PORT} >> "logs/validator${i}.log" 2>&1 &
done

echo "All started"
ps aux | grep -E "geth|prysm|beacon|validator" | grep -v grep | wc -l
