#!/bin/bash
# pos.sh — single manager for the private Ethereum PoS devnet
# Usage: ./pos.sh [options] <command>
#   ./pos.sh setup
#   ./pos.sh start
#   ./pos.sh stop
#   ./pos.sh restart
#   ./pos.sh status
#   ./pos.sh logs [geth|beacon|validator] [n]
#   ./pos.sh deposit
#   ./pos.sh clients

set -e

cd "$(dirname "$0")"

# ── Options ───────────────────────────────────────────────────────
CLIENT=""
NETWORK=""
while [[ "$1" =~ ^-- ]]; do
  case "$1" in
    --client) CLIENT="$2"; shift 2 ;;
    --network) NETWORK="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Export recognized env vars if flags were passed (defaults are handled inside)
[ -n "$CLIENT" ] && export CLIENT="$CLIENT"
[ -n "$NETWORK" ] && export NETWORK="$NETWORK"

CMD="${1:-help}"
shift || true

NUM_NODES=9

case "$CMD" in
  setup)
    echo "==> Running setup (download binaries, generate genesis, start processes)"
    ./run-pos.sh
    ;;

  start)
    if pgrep -f "beacon-chain|validator|geth" >/dev/null 2>&1; then
      echo "Processes already running. Run './pos.sh restart' to restart."
      exit 0
    fi
    echo "==> Starting devnet processes"
    ./run-pos.sh
    ;;

  stop)
    echo "==> Stopping devnet processes"
    ./stop-all.sh
    ;;

  restart)
    echo "==> Restarting devnet"
    ./stop-all.sh || true
    sleep 3
    ./run-pos.sh
    ;;

  status)
    echo "==> Devnet status"
    # Process count
    PROCS=$(ps aux | grep -E "geth|beacon-chain|validator" | grep -v grep | wc -l)
    echo "Processes running: $PROCS"

    # Geth status
    GETH_BLOCK=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://localhost:8541 2>/dev/null | python3 -c "import sys,json; print(int(json.load(sys.stdin)['result'], 16))" 2>/dev/null || echo "n/a")
    GETH_PEERS=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' http://localhost:8541 2>/dev/null | python3 -c "import sys,json; print(int(json.load(sys.stdin)['result'], 16))" 2>/dev/null || echo "n/a")
    GETH_SYNCING=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' http://localhost:8541 2>/dev/null | python3 -c "import sys,json; r=json.load(sys.stdin)['result']; print('syncing' if r else 'synced')" 2>/dev/null || echo "n/a")
    echo "Geth block: $GETH_BLOCK | peers: $GETH_PEERS | sync: $GETH_SYNCING"

    # Beacon status
    HEAD=$(curl -s http://localhost:3500/eth/v1/beacon/headers/head 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['header']['message']['slot'])" 2>/dev/null || echo "n/a")
    FINALIZED=$(curl -s http://localhost:3500/eth/v1/beacon/states/head/finality_checkpoints 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['finalized']['epoch'])" 2>/dev/null || echo "n/a")
    JUSTIFIED=$(curl -s http://localhost:3500/eth/v1/beacon/states/head/finality_checkpoints 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['current_justified']['epoch'])" 2>/dev/null || echo "n/a")
    ACTIVE=$(curl -s http://localhost:3500/eth/v1/beacon/states/head/validators 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin)['data']; print(sum(1 for v in d if v['status']=='active_ongoing'))" 2>/dev/null || echo "n/a")
    PENDING=$(curl -s http://localhost:3500/eth/v1/beacon/states/head/validators 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin)['data']; print(sum(1 for v in d if v['status']=='pending_queued'))" 2>/dev/null || echo "n/a")
    echo "Beacon head slot: $HEAD | finalized epoch: $FINALIZED | justified epoch: $JUSTIFIED"
    echo "Validators active: $ACTIVE | pending: $PENDING"
    ;;

  logs)
    TARGET="${1:-beacon}"
    N="${2:-50}"
    case "$TARGET" in
      geth|g*)
        NODE="${2:-1}"
        N="${3:-50}"
        tail -n "$N" "logs/geth${NODE}.log"
        ;;
      beacon|b*)
        NODE="${2:-1}"
        N="${3:-50}"
        tail -n "$N" "logs/beacon${NODE}.log"
        ;;
      validator|v*)
        NODE="${2:-1}"
        N="${3:-50}"
        tail -n "$N" "logs/validator${NODE}.log"
        ;;
      *)
        echo "Usage: ./pos.sh logs [geth|beacon|validator] [node_number] [lines]"
        echo "Example: ./pos.sh logs beacon 1 100"
        exit 1
        ;;
    esac
    ;;

  deposit)
    echo "==> Sending validator deposits"
    if [ -f "send_deposits_9.py" ]; then
      python3 send_deposits_9.py
    else
      echo "ERROR: send_deposits_9.py not found"
      exit 1
    fi
    ;;

  clients)
    echo "==> Client matrix"
    printf "%-12s %-12s %-30s %s\n" "CLIENT" "VERSION" "BINARY" "STATUS"
    GETH_BIN="./geth-1.17.4"
    if [ -x "$GETH_BIN" ]; then
      printf "%-12s %-12s %-30s %s\n" "geth" "1.17.4" "$GETH_BIN" "ready"
    else
      printf "%-12s %-12s %-30s %s\n" "geth" "1.17.4" "$GETH_BIN" "missing (run ./pos.sh setup)"
    fi
    for p in beacon-chain validator prysmctl; do
      BIN="./${p}-v5.3.2"
      if [ -x "$BIN" ]; then
        printf "%-12s %-12s %-30s %s\n" "$p" "v5.3.2" "$BIN" "ready"
      else
        printf "%-12s %-12s %-30s %s\n" "$p" "v5.3.2" "$BIN" "missing (run ./pos.sh setup)"
      fi
    done
    ;;

  help|--help|-h|"")
    echo "pos.sh — private Ethereum PoS devnet manager"
    echo ""
    echo "Usage: ./pos.sh [options] <command>"
    echo ""
    echo "Commands:"
    echo "  setup      Download binaries, generate genesis, start all nodes"
    echo "  start      Start the devnet (same as setup if not running)"
    echo "  stop       Stop all devnet processes"
    echo "  restart    Stop then start the devnet"
    echo "  status     Show block, slot, peers, validators, finality"
    echo "  logs       Tail live logs (geth|beacon|validator) [node] [lines]"
    echo "  deposit    Send 32 ETH deposits for validator set"
    echo "  clients    Print client matrix"
    echo "  help       Show this help"
    echo ""
    echo "Examples:"
    echo "  ./pos.sh setup"
    echo "  ./pos.sh status"
    echo "  ./pos.sh logs beacon 1 100"
    echo "  ./pos.sh logs validator 3 50"
    ;;

  *)
    echo "Unknown command: $CMD"
    echo "Run './pos.sh help' for usage."
    exit 1
    ;;
esac
