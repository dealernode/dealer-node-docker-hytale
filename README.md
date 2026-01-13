# 🎮 Hytale Server Docker Image

Unofficial Docker image for running Hytale game servers.

[![Build Status](https://github.com/dealernode/dealer-node-docker-hytale/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/dealernode/dealer-node-docker-hytale/actions)

## Features

- ✅ Java 25 (Adoptium Temurin) on Debian (glibc for QUIC support)
- ✅ Automatic server file download via `hytale-downloader`
- ✅ **Automatic OAuth2 token refresh** - no manual token regeneration needed
- ✅ Multi-architecture support
- ✅ Non-root user for security
- ✅ Health checks included
- ✅ Persistent world data support

---

## Quick Start

### Prerequisites

1. **Hytale Account** with server access
2. **OAuth2 Refresh Token** from `hytale-downloader`

### Getting Your Credentials

```bash
# Download hytale-downloader from Hytale's official site
curl -L -o hytale-downloader.zip "https://downloader.hytale.com/hytale-downloader.zip"
unzip hytale-downloader.zip
chmod +x hytale-downloader-linux-amd64

# Run and complete OAuth2 authentication in your browser
./hytale-downloader-linux-amd64

# Find your credentials (full JSON content needed)
cat .hytale-downloader-credentials.json
# Output: {"access_token":"...","refresh_token":"...","expires_at":...,"branch":"release"}
```

---

## Running the Server

### Docker CLI

```bash
docker run -d \
  --name hytale-server \
  -p 5520:5520/udp \
  -e HYTALE_CREDENTIALS_JSON='{"access_token":"...","refresh_token":"...","expires_at":...,"branch":"release"}' \
  -e SERVER_NAME="My Hytale Server" \
  -e MAX_PLAYERS=20 \
  -v hytale-data:/server/universe \
  ghcr.io/dealernode/hytale-server:latest
```

### Docker Compose

```yaml
version: '3.8'

services:
  hytale:
    image: ghcr.io/dealernode/hytale-server:latest
    container_name: hytale-server
    ports:
      - "5520:5520/udp"
    environment:
      - HYTALE_CREDENTIALS_JSON={"access_token":"...","refresh_token":"...","expires_at":...,"branch":"release"}
      - SERVER_NAME=My Hytale Server
      - MAX_PLAYERS=20
      - MEMORY_MB=4096
    volumes:
      - hytale-universe:/server/universe
      - hytale-mods:/server/mods
    restart: unless-stopped

volumes:
  hytale-universe:
  hytale-mods:
```

---

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `HYTALE_CREDENTIALS_JSON` | ✅ **Yes** | - | Full JSON from `.hytale-downloader-credentials.json` |
| `SERVER_NAME` | No | `Hytale Server - (Dealer Node)` | Server display name |
| `MAX_PLAYERS` | No | `10` | Maximum concurrent players |
| `MEMORY_MB` | No | `4096` | JVM heap size in MB |
| `AUTH_MODE` | No | `authenticated` | `authenticated` or `offline` |
| `SKIP_UPDATE_CHECK` | No | `false` | Skip server file update check |

---

## System Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| **RAM** | 4 GB | 6+ GB |
| **CPU** | 2 cores | 4 cores |
| **Storage** | 10 GB | 20+ GB |
| **Network** | UDP port 5520 | - |

---

## Volumes

Mount these paths for persistent data:

| Path | Description |
|------|-------------|
| `/server/universe` | World data and player saves |
| `/server/mods` | Server mods |

---

## Connecting to Your Server

Once the server is running, players can connect using:

```
Server Address: <your-server-ip>
Port: 5520
```

> ⚠️ **Note:** Hytale uses the QUIC protocol over UDP. Make sure UDP port 5520 is open in your firewall.

---

## Cloud Deployment Examples

### AWS EC2 / Lightsail

```bash
# Install Docker
sudo apt update && sudo apt install -y docker.io

# Run the server
sudo docker run -d \
  --name hytale \
  -p 5520:5520/udp \
  -e HYTALE_CREDENTIALS_JSON='{...}' \
  -v hytale-data:/server/universe \
  ghcr.io/dealernode/hytale-server:latest
```

### DigitalOcean Droplet

Same as AWS - just ensure you select a droplet with at least 4GB RAM.

### Google Cloud / Azure

Use Container Instances or a VM with Docker installed.

### Pterodactyl Panel

Create a custom egg using this image with:
- **Docker Image:** `ghcr.io/dealernode/hytale-server:latest`
- **Startup Command:** (leave empty, uses entrypoint)
- **Default Port:** `5520/udp`

---

## Building Locally

```bash
git clone https://github.com/dealernode/dealer-node-docker-hytale.git
cd dealer-node-docker-hytale

# Build
docker build -t hytale-server .

# Run
docker run -d -p 5520:5520/udp -e HYTALE_CREDENTIALS_JSON='{...}' hytale-server
```

---

## Troubleshooting

### Server won't start
- Check that `HYTALE_CREDENTIALS_JSON` is set correctly (must be full JSON)
- Verify you have at least 4GB RAM available
- Check logs: `docker logs hytale-server`

### Can't connect to server
- Ensure UDP port 5520 is open in your firewall
- Check that the server finished starting (look for "Server started" in logs)
- Verify your IP address is correct

### Token expired
The server **automatically refreshes tokens** using the OAuth2 endpoint. If you still get token errors, the refresh token itself may have expired (after ~30 days of inactivity). In this case, re-run `hytale-downloader` to get new credentials.

---

## License

This is an unofficial community project. Hytale is a trademark of Hypixel Studios.

---

## Contributing

Pull requests welcome! Please open an issue first to discuss major changes.
