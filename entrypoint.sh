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

# OAuth2 Token endpoint for refreshing tokens
OAUTH_TOKEN_URL="https://oauth.accounts.hytale.com/oauth2/token"
CLIENT_ID="hytale-downloader"

# Function to refresh token if expired
refresh_token_if_needed() {
    local expires_at=$(echo "$HYTALE_CREDENTIALS_JSON" | jq -r '.expires_at // 0')
    local current_time=$(date +%s)
    local buffer=300  # 5 minutes buffer
    
    if [ "$expires_at" -le "$((current_time + buffer))" ]; then
        echo "[Dealer Node] Access token expired or expiring soon, refreshing..."
        
        local refresh_token=$(echo "$HYTALE_CREDENTIALS_JSON" | jq -r '.refresh_token')
        
        if [ -z "$refresh_token" ] || [ "$refresh_token" = "null" ]; then
            echo "[ERROR] No refresh token available"
            return 1
        fi
        
        # Call OAuth2 token endpoint to refresh
        local response=$(curl -s -X POST "$OAUTH_TOKEN_URL" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -d "grant_type=refresh_token" \
            -d "client_id=$CLIENT_ID" \
            -d "refresh_token=$refresh_token")
        
        # Check if refresh was successful
        local new_access_token=$(echo "$response" | jq -r '.access_token // empty')
        
        if [ -z "$new_access_token" ]; then
            echo "[ERROR] Failed to refresh token: $(echo "$response" | jq -r '.error_description // .error // "Unknown error"')"
            return 1
        fi
        
        # Update credentials with new tokens
        local new_refresh_token=$(echo "$response" | jq -r '.refresh_token // empty')
        local new_expires_in=$(echo "$response" | jq -r '.expires_in // 3600')
        local new_expires_at=$((current_time + new_expires_in))
        local branch=$(echo "$HYTALE_CREDENTIALS_JSON" | jq -r '.branch // "release"')
        
        HYTALE_CREDENTIALS_JSON=$(jq -n \
            --arg at "$new_access_token" \
            --arg rt "${new_refresh_token:-$refresh_token}" \
            --argjson ea "$new_expires_at" \
            --arg br "$branch" \
            '{access_token: $at, refresh_token: $rt, expires_at: $ea, branch: $br}')
        
        echo "[Dealer Node] Token refreshed successfully (expires at: $(date -d @$new_expires_at 2>/dev/null || date -r $new_expires_at 2>/dev/null || echo $new_expires_at))"
    else
        echo "[Dealer Node] Access token still valid (expires at: $(date -d @$expires_at 2>/dev/null || date -r $expires_at 2>/dev/null || echo $expires_at))"
    fi
}

# Refresh token if needed before proceeding
refresh_token_if_needed

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

# Detect OS and set the correct hytale-downloader binary name
if [ -f "./hytale-downloader.exe" ]; then
    DOWNLOADER="./hytale-downloader.exe"
elif [ -f "./hytale-downloader" ]; then
    DOWNLOADER="./hytale-downloader"
else
    echo "[ERROR] hytale-downloader not found"
    exit 1
fi
echo "[Dealer Node] Using downloader: $DOWNLOADER"

if [ ! -f "HytaleServer.jar" ]; then
    echo "[Dealer Node] Downloading server files..."
    $DOWNLOADER -download-path server-files.zip
    
    if [ -f "server-files.zip" ]; then
        echo "[Dealer Node] Unzipping server files..."
        unzip -q -o server-files.zip -d .
        rm server-files.zip
        
        # Check if files were extracted to a Server/ subdirectory (common in Hytale zips)
        if [ -d "Server" ] && [ -f "Server/HytaleServer.jar" ]; then
            echo "[Dealer Node] Detected 'Server' subdirectory, moving files to root..."
            mv Server/* .
            rmdir Server
        fi
        
        echo "[Dealer Node] Server files downloaded and extracted successfully"
    else
        echo "[ERROR] Failed to download server files"
        exit 1
    fi
else
    echo "[Dealer Node] Server files already present"
    
    # Check for updates
    if [ "${SKIP_UPDATE_CHECK:-false}" != "true" ]; then
        echo "[Dealer Node] Checking for updates..."
        $DOWNLOADER -check-update || true
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
echo "[Dealer Node] Auth Mode: ${AUTH_MODE}"
echo "[Dealer Node] Bind: 0.0.0.0:5520"
echo ""

# Build JVM arguments - let JVM use maximum available memory
# UseContainerSupport makes JVM aware of container memory limits
# MaxRAMPercentage sets how much of available memory to use (90%)
JVM_ARGS="-XX:+UseContainerSupport"
JVM_ARGS="$JVM_ARGS -XX:MaxRAMPercentage=90.0"
JVM_ARGS="$JVM_ARGS -XX:InitialRAMPercentage=50.0"

# Performance tuning for containers
JVM_ARGS="$JVM_ARGS -XX:+UseG1GC"
JVM_ARGS="$JVM_ARGS -XX:MaxGCPauseMillis=50"
JVM_ARGS="$JVM_ARGS -XX:+UseStringDeduplication"

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

# Execute the server using JAR (cross-platform)
echo "[Dealer Node] Executing: java $JVM_ARGS -jar HytaleServer.jar $SERVER_ARGS"
exec java $JVM_ARGS -jar HytaleServer.jar $SERVER_ARGS
