#!/bin/bash
cd ~/eth-pos/private-pos
pkill -9 validator
sleep 2
./prysm.sh validator --datadir beacon1/validator --accept-terms-of-use --chain-config-file config.yaml --interop-num-validators 64 --interop-start-index 0 --beacon-rest-api-provider http://localhost:3500 >> logs/validator1.log 2>&1 &
echo "64 validators started"
