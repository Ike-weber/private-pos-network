#!/bin/bash
set -e

cd "$(dirname "$0")"

GETH_VERSION="1.17.4"
GETH_COMMIT="36a7dc72"
PRYSM_VERSION="v7.1.6"

OS=$(uname -s)
ARCH=$(uname -m)

case "$OS" in
  Linux*)     PLATFORM="linux" ;;
  Darwin*)    PLATFORM="darwin" ;;
  CYGWIN*|MINGW*|MSYS*)
    echo "WARNING: Native Windows detected. If you are using WSL, run this script inside WSL (Ubuntu), not PowerShell/CMD."
    echo "Trying Windows binaries as fallback..."
    PLATFORM="windows"
    ;;
  *)          echo "ERROR: Unsupported OS: $OS"; exit 1 ;;
esac

case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  *) echo "ERROR: Unsupported architecture: $ARCH"; exit 1 ;;
esac

echo "Detected platform: $PLATFORM-$ARCH"

# ── Download Geth ───────────────────────────────────────────────────
GETH_BIN="./geth-${GETH_VERSION}"
if [ -x "$GETH_BIN" ]; then
  echo "Geth ${GETH_VERSION} already present."
else
  if [ "$PLATFORM" = "linux" ]; then
    GETH_TGZ="geth-${PLATFORM}-${ARCH}-${GETH_VERSION}-${GETH_COMMIT}.tar.gz"
    AZURE_URL="https://gethstore.blob.core.windows.net/builds/${GETH_TGZ}"
    GITHUB_URL="https://github.com/ethereum/go-ethereum/releases/download/v${GETH_VERSION}/${GETH_TGZ}"
  elif [ "$PLATFORM" = "darwin" ]; then
    GETH_TGZ="geth-${PLATFORM}-${ARCH}-${GETH_VERSION}-${GETH_COMMIT}.tar.gz"
    GITHUB_URL="https://github.com/ethereum/go-ethereum/releases/download/v${GETH_VERSION}/${GETH_TGZ}"
    AZURE_URL=""
  else
    echo "ERROR: Windows native not supported. Use WSL."
    exit 1
  fi

  TMP_TGZ="geth-${GETH_VERSION}.tar.gz"
  TMP_DIR="geth-${PLATFORM}-${ARCH}-${GETH_VERSION}-${GETH_COMMIT}"

  DOWNLOADED=false
  for URL in "$AZURE_URL" "$GITHUB_URL"; do
    [ -z "$URL" ] && continue
    echo "Downloading Geth from $URL ..."
    if curl -L --fail --max-time 180 "$URL" -o "$TMP_TGZ" 2>/dev/null; then
      DOWNLOADED=true
      break
    fi
    echo "  failed, trying next source..."
  done

  if [ "$DOWNLOADED" != "true" ]; then
    echo "ERROR: Could not download Geth ${GETH_VERSION} automatically."
    echo "Please download it manually from https://github.com/ethereum/go-ethereum/releases"
    exit 1
  fi

  tar xzf "$TMP_TGZ"
  mv "${TMP_DIR}/geth" "$GETH_BIN"
  chmod +x "$GETH_BIN"
  rm -rf "$TMP_DIR" "$TMP_TGZ"
  echo "Geth ${GETH_VERSION} ready: $GETH_BIN"
fi

# ── Download Prysm ──────────────────────────────────────────────────
PRYSM_BINS=("beacon-chain" "validator" "prysmctl")
mkdir -p dist

for bin in "${PRYSM_BINS[@]}"; do
  FILE="dist/${bin}-${PRYSM_VERSION}-${PLATFORM}-${ARCH}"
  LINK="./${bin}-${PRYSM_VERSION}"

  if [ -x "$LINK" ] && [ -x "$FILE" ]; then
    echo "${bin} ${PRYSM_VERSION} already present."
    continue
  fi

  URL="https://github.com/OffchainLabs/prysm/releases/download/${PRYSM_VERSION}/${bin}-${PRYSM_VERSION}-${PLATFORM}-${ARCH}"
  echo "Downloading ${bin} from $URL ..."
  if curl -L --fail --max-time 180 "$URL" -o "$FILE" 2>/dev/null; then
    chmod +x "$FILE"
    ln -sf "$FILE" "$LINK"
    echo "${bin} ${PRYSM_VERSION} ready: $LINK"
  else
    echo "ERROR: Could not download ${bin} ${PRYSM_VERSION} automatically."
    echo "Please download it manually from https://github.com/OffchainLabs/prysm/releases"
    exit 1
  fi
done

echo ""
echo "All binaries are ready."
echo "Geth:    $GETH_BIN"
echo "Prysm:   ./beacon-chain-${PRYSM_VERSION} ./validator-${PRYSM_VERSION} ./prysmctl-${PRYSM_VERSION}"
