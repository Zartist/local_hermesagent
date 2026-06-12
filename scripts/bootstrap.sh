#!/bin/sh
# Bootstrap portable Hermes in moodledata/.hermes/
# All artifacts survive pod restarts (NFS-backed)

HERMES_HOME="/var/www/moodledata/.hermes"
echo "=== Hermes Portable Bootstrap ==="
echo "Target: $HERMES_HOME"
echo ""

mkdir -p "$HERMES_HOME"

# Step 1: Download standalone Python if needed
PYTHON_BIN="$HERMES_HOME/python/bin/python3.12"
if [ ! -f "$PYTHON_BIN" ]; then
    echo "[1/4] Downloading standalone Python (musl)..."
    ARCH=$(uname -m)
    echo "  Architecture: $ARCH"
    case "$ARCH" in
        x86_64) ARCH_URL="x86_64" ;;
        aarch64) ARCH_URL="aarch64" ;;
        *) echo "ERROR: Unsupported architecture: $ARCH"; exit 1 ;;
    esac

    TAG="20260610"
    PYVER="3.12.13"
    URL="https://github.com/astral-sh/python-build-standalone/releases/download/${TAG}/cpython-${PYVER}%2B${TAG}-${ARCH_URL}-unknown-linux-musl-install_only.tar.gz"

    echo "  URL: $URL"
    TMPFILE="$HERMES_HOME/python.tar.gz"

    echo "  Downloading (may take 1-2 minutes)..."
    if curl -fSL --progress-bar -o "$TMPFILE" "$URL" 2>&1; then
        SIZE=$(du -h "$TMPFILE" 2>/dev/null | cut -f1)
        echo "  Downloaded: $SIZE"

        echo "  Extracting..."
        mkdir -p "$HERMES_HOME/python"
        tar xzf "$TMPFILE" -C "$HERMES_HOME/python" --strip-components=1 2>&1
        rm -f "$TMPFILE"
        echo "  Python installed: $PYTHON_BIN"
    else
        echo "ERROR: Failed to download Python from $URL"
        rm -f "$TMPFILE"
        exit 1
    fi
else
    echo "[1/4] Python already installed: $PYTHON_BIN"
fi
echo ""

# Step 2: Create virtual environment
if [ ! -f "$HERMES_HOME/venv/bin/python" ]; then
    echo "[2/4] Creating virtual environment..."
    "$PYTHON_BIN" -m venv "$HERMES_HOME/venv"
    echo "  venv created at $HERMES_HOME/venv"
else
    echo "[2/4] venv already exists"
fi
echo ""

# Step 3: Install packages
echo "[3/4] Installing hermes-agent + pymysql..."
"$HERMES_HOME/venv/bin/python" -m pip install --quiet hermes-agent pymysql 2>&1
HERMES_VERSION=$("$HERMES_HOME/venv/bin/hermes" --version 2>&1)
echo "  $HERMES_VERSION"
echo "  pymysql installed"
echo ""

# Step 4: Verify
echo "[4/4] Verifying installation..."
if "$HERMES_HOME/venv/bin/hermes" --version >/dev/null 2>&1; then
    echo "  hermes: OK"
    if "$HERMES_HOME/venv/bin/hermes" acp --help >/dev/null 2>&1; then
        echo "  hermes acp: OK"
    else
        echo "  hermes acp: needs config"
    fi
else
    echo "  WARNING: hermes --version failed"
fi

echo ""
echo "=== Bootstrap complete ==="
echo "HERMES_HOME=$HERMES_HOME"
echo "To use: HERMES_HOME=$HERMES_HOME $HERMES_HOME/venv/bin/hermes acp"
