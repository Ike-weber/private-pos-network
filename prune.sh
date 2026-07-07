#!/bin/bash
set -e

# prune.sh — Geth database maintenance: prune state and ancient data
# Usage: ./prune.sh [node_number]

cd "$(dirname "$0")"
NODE="${1:-1}"
DATADIR="node${NODE}/geth"

echo "==> Pruning state trie for node${NODE}"
./geth snapshot prune-state --datadir "node${NODE}"

echo "==> Done. Inspect disk usage:"
du -sh "node${NODE}"
