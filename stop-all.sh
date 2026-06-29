#!/bin/bash
# Stop all devnet processes

pkill -f geth || true
pkill -f prysm.sh || true
pkill -f beacon-chain || true
pkill -f validator || true

sleep 2

# Force kill any survivors
pkill -9 -f geth || true
pkill -9 -f prysm.sh || true
pkill -9 -f beacon-chain || true
pkill -9 -f validator || true

echo "All devnet processes stopped"
