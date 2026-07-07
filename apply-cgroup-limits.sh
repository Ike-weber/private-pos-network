#!/bin/bash
# apply-cgroup-limits.sh — apply memory + CPU limits to all devnet processes
# Usage: sudo ./apply-cgroup-limits.sh

CGROUP=/sys/fs/cgroup/devnet-limit

mkdir -p "$CGROUP"
echo "8G" > "$CGROUP"/memory.max
echo "400000" > "$CGROUP"/cpu.max  # 4 cores in microseconds per sec

for pid in $(pgrep -f "geth|beacon-chain|validator"); do
  echo "$pid" > "$CGROUP"/cgroup.procs 2>/dev/null || true
done

echo "Cgroup limits applied to $CGROUP"
