#!/bin/bash
# ==============================================================================
# Hytale Server Entrypoint
# ==============================================================================
# Handles server file download, configuration, and startup.
# ==============================================================================

set -e

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║              Dealer Node - Hytale Server                         ║"
echo "╚══════════════════════════════════════════════════════════════════╝"

# ------------------------------------------------------------------------------
# Validate required environment variables
# ------------------------------------------------------------------------------
if [ -z "$HYTALE_CREDENTIALS_JSON" ]; then
    echo "[ERROR] HYTALE_CREDENTIALS_JSON is required but not set"
    echo "[ERROR] Please provide the full contents of .hytale-downloader-credentials.json"
    exit 1
fi

# ------------------------------------------------------------------------------
# Configure hytale-downloader authentication
# ------------------------------------------------------------------------------
echo "[Dealer Node] Configuring authentication..."

# The hytale-downloader stores credentials in .hytale-downloader-credentials.json
# We inject the pre-obtained credentials via environment variable
# Format based on actual hytale-downloader behavior
cat > .hytale-downloader-credentials.json << EOF
${HYTALE_CREDENTIALS_JSON}
EOF

chmod 600 .hytale-downloader-credentials.json
echo "[Dealer Node] Credentials configured"

# ------------------------------------------------------------------------------
# Download/update server files
# ------------------------------------------------------------------------------
if [ ! -f "HytaleServer.jar" ]; then
    echo "[Dealer Node] Downloading server files..."
    ./hytale-downloader -download-path server-files.zip
    
    if [ -f "server-files.zip" ]; then
        unzip -o server-files.zip -d .
        rm server-files.zip
        echo "[Dealer Node] Server files downloaded successfully"
    else
        echo "[ERROR] Failed to download server files"
        exit 1
    fi
else
    echo "[Dealer Node] Server files already present"
    
    # Check for updates
    if [ "${SKIP_UPDATE_CHECK:-false}" != "true" ]; then
        echo "[Dealer Node] Checking for updates..."
        ./hytale-downloader -check-update || true
    fi
fi

# ------------------------------------------------------------------------------
# Verify required files exist
# ------------------------------------------------------------------------------
if [ ! -f "HytaleServer.jar" ]; then
    echo "[ERROR] HytaleServer.jar not found after download"
    exit 1
fi

if [ ! -f "Assets.zip" ] && [ ! -d "Assets" ]; then
    echo "[WARNING] Assets not found - server may not start correctly"
fi

# Determine assets path
ASSETS_PATH=""
if [ -f "Assets.zip" ]; then
    ASSETS_PATH="Assets.zip"
elif [ -d "Assets" ]; then
    ASSETS_PATH="Assets"
fi

# ------------------------------------------------------------------------------
# Start the server
# ------------------------------------------------------------------------------
echo "[Dealer Node] Starting Hytale Server..."
echo "[Dealer Node] Server Name: ${SERVER_NAME}"
echo "[Dealer Node] Max Players: ${MAX_PLAYERS}"
echo "[Dealer Node] Memory: ${MEMORY_MB}MB"
echo "[Dealer Node] Auth Mode: ${AUTH_MODE}"
echo "[Dealer Node] Bind: 0.0.0.0:5520"
echo ""

# Build JVM arguments
JVM_ARGS="-Xms${MEMORY_MB}M -Xmx${MEMORY_MB}M"

# Performance tuning for containers
JVM_ARGS="$JVM_ARGS -XX:+UseG1GC"
JVM_ARGS="$JVM_ARGS -XX:MaxGCPauseMillis=50"
JVM_ARGS="$JVM_ARGS -XX:+UseStringDeduplication"

# Container awareness
JVM_ARGS="$JVM_ARGS -XX:+UseContainerSupport"

# Build server arguments
SERVER_ARGS="--bind 0.0.0.0:5520"
SERVER_ARGS="$SERVER_ARGS --auth-mode $AUTH_MODE"
SERVER_ARGS="$SERVER_ARGS --disable-sentry"

if [ -n "$ASSETS_PATH" ]; then
    SERVER_ARGS="$SERVER_ARGS --assets $ASSETS_PATH"
fi

# Pass any additional arguments from command line
if [ $# -gt 0 ]; then
    SERVER_ARGS="$SERVER_ARGS $@"
fi

# Execute the server (exec replaces shell process)
echo "[Dealer Node] Executing: java $JVM_ARGS -jar HytaleServer.jar $SERVER_ARGS"
exec java $JVM_ARGS -jar HytaleServer.jar $SERVER_ARGS
