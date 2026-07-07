#!/bin/bash
set -e

# rpc-auth.sh — generate API key file and TLS cert for Geth RPC
# Usage: ./rpc-auth.sh [regen]

cd "$(dirname "$0")"

if [ ! -f "rpc-key.pem" ] || [ ! -f "rpc-cert.pem" ] || [ "$1" == "regen" ]; then
  echo "==> Generating self-signed TLS certificate for RPC"
  rm -f rpc-key.pem rpc-cert.pem
  openssl req -x509 -newkey rsa:2048 -keyout rpc-key.pem -out rpc-cert.pem -days 365 -nodes -subj "/CN=localhost"
  chmod 600 rpc-key.pem rpc-cert.pem
  echo "TLS cert ready: rpc-cert.pem"
fi

if [ ! -f "rpc-users.txt" ] || [ "$1" == "regen" ]; then
  echo "==> Generating RPC user credentials"
  # user: harsh, random 32-char password
  PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c32)
  # htpasswd format for geth --http.rpcprefix / --http.api auth not directly supported; use simple token instead
  echo "harsh:$PASSWORD" > rpc-users.txt
  chmod 600 rpc-users.txt
  echo "API user: harsh | password: $PASSWORD"
  echo "Saved to rpc-users.txt"
else
  echo "RPC users already exist: rpc-users.txt"
fi
