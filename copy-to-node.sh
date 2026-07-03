#!/bin/bash
# Usage: bash copy-to-node.sh <node_id> <user@host>
# Example: bash copy-to-node.sh 2 root@10.0.0.2
set -e

NODE_ID=$1
TARGET=$2

if [ -z "$NODE_ID" ] || [ -z "$TARGET" ]; then
  echo "Usage: bash copy-to-node.sh <node_id> <user@host>"
  exit 1
fi

echo "Copying devnet files to node $NODE_ID at $TARGET..."

ssh $TARGET "mkdir -p ~/pos-devnet"

scp config.yaml genesis.json genesis.ssz jwt.hex distributed-start.sh \
  geth-1.17.4 beacon-chain-v5.3.2 validator-v5.3.2 \
  $TARGET:~/pos-devnet/

echo "Node $NODE_ID files copied."
echo "Next: ssh $TARGET, cd ~/pos-devnet, and run distributed-start.sh with the correct env vars."
