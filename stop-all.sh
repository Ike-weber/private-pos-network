#!/bin/bash
pkill -f geth
pkill -f prysm
pkill -f validator
pkill -f prysm.sh
sleep 2
pkill -9 -f geth
pkill -9 -f prysm
pkill -9 -f validator
pkill -9 -f prysm.sh
echo "All devnet processes stopped"
