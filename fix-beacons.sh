#!/bin/bash
cd ~/eth-pos/private-pos

# Kill old beacons
ps aux | grep "beacon-chain.*beacon2\|beacon-chain.*beacon3" | grep -v grep | awk '{print $2}' | xargs -r kill -9 2>/dev/null
sleep 2

# Start beacon2 with correct bootstrap
./prysm.sh beacon-chain --datadir beacon2 --min-sync-peers 0 --genesis-state genesis.ssz --interop-eth1data-votes --chain-config-file config.yaml --contract-deployment-block 0 --chain-id 12345 --accept-terms-of-use --jwt-secret jwt.hex --suggested-fee-recipient 0xC4d87b80780117F805D620c4FF88e5380699dB41 --execution-endpoint http://localhost:8552 --rpc-port 4001 --grpc-gateway-port 3501 --p2p-tcp-port 13001 --p2p-udp-port 12001 --bootstrap-node=/ip4/172.25.235.198/tcp/13000/p2p/16Uiu2HAm5zTzNRcJQM2fA88oXchkXcvprYo57nNYz4gKYV42519g >> logs/beacon2.log 2>&1 &
echo "Beacon2 started"
sleep 3

# Start beacon3 with correct bootstrap
./prysm.sh beacon-chain --datadir beacon3 --min-sync-peers 0 --genesis-state genesis.ssz --interop-eth1data-votes --chain-config-file config.yaml --contract-deployment-block 0 --chain-id 12345 --accept-terms-of-use --jwt-secret jwt.hex --suggested-fee-recipient 0x2F54526037527688d3b2DEFA3a0B1F4CAf78dB8F --execution-endpoint http://localhost:8553 --rpc-port 4002 --grpc-gateway-port 3502 --p2p-tcp-port 13002 --p2p-udp-port 12002 --bootstrap-node=/ip4/172.25.235.198/tcp/13000/p2p/16Uiu2HAm5zTzNRcJQM2fA88oXchkXcvprYo57nNYz4gKYV42519g >> logs/beacon3.log 2>&1 &
echo "Beacon3 started"
sleep 5

# Check processes
ps aux | grep "beacon-chain" | grep -v grep | wc -l
