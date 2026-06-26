#!/bin/bash
cd ~/eth-pos/private-pos
export PRYSM_ALLOW_UNVERIFIED_BINARIES=1

# Start beacon nodes
./prysm.sh beacon-chain --datadir beacon1 --min-sync-peers 0 --genesis-state genesis.ssz --bootstrap-node= --interop-eth1data-votes --chain-config-file config.yaml --contract-deployment-block 0 --chain-id 12345 --accept-terms-of-use --jwt-secret jwt.hex --suggested-fee-recipient 0x8B0681dBD724dcaC48b433e9df8A220D47C94a19 --execution-endpoint http://localhost:8551 --rpc-port 4000 --grpc-gateway-port 3500 --p2p-tcp-port 13000 --p2p-udp-port 12000 >> logs/beacon1.log 2>&1 &

./prysm.sh beacon-chain --datadir beacon2 --min-sync-peers 0 --genesis-state genesis.ssz --bootstrap-node= --interop-eth1data-votes --chain-config-file config.yaml --contract-deployment-block 0 --chain-id 12345 --accept-terms-of-use --jwt-secret jwt.hex --suggested-fee-recipient 0xC4d87b80780117F805D620c4FF88e5380699dB41 --execution-endpoint http://localhost:8552 --rpc-port 4001 --grpc-gateway-port 3501 --p2p-tcp-port 13001 --p2p-udp-port 12001 >> logs/beacon2.log 2>&1 &

./prysm.sh beacon-chain --datadir beacon3 --min-sync-peers 0 --genesis-state genesis.ssz --bootstrap-node= --interop-eth1data-votes --chain-config-file config.yaml --contract-deployment-block 0 --chain-id 12345 --accept-terms-of-use --jwt-secret jwt.hex --suggested-fee-recipient 0x2F54526037527688d3b2DEFA3a0B1F4CAf78dB8F --execution-endpoint http://localhost:8553 --rpc-port 4002 --grpc-gateway-port 3502 --p2p-tcp-port 13002 --p2p-udp-port 12002 >> logs/beacon3.log 2>&1 &

sleep 15

# Start validators
./prysm.sh validator --datadir beacon1/validator --accept-terms-of-use --chain-config-file config.yaml --wallet-dir validator-keys --wallet-password-file validator-keys/password.txt --beacon-rest-api-provider http://localhost:3500 >> logs/validator1.log 2>&1 &

./prysm.sh validator --datadir beacon2/validator --accept-terms-of-use --chain-config-file config.yaml --wallet-dir validator-keys --wallet-password-file validator-keys/password.txt --beacon-rest-api-provider http://localhost:3501 >> logs/validator2.log 2>&1 &

./prysm.sh validator --datadir beacon3/validator --accept-terms-of-use --chain-config-file config.yaml --wallet-dir validator-keys --wallet-password-file validator-keys/password.txt --beacon-rest-api-provider http://localhost:3502 >> logs/validator3.log 2>&1 &

echo "All Prysm processes started"
