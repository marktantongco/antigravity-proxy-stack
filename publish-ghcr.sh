#!/bin/bash
# Build and publish images to GitHub Container Registry

set -e

REPO_OWNER="${1:-your-github-username}"
REPO_NAME="${2:-antigravity-proxy-stack}"
VERSION="${3:-latest}"

echo "=== PUBLISHING TO GHCR ==="
echo "Registry: ghcr.io/$REPO_OWNER"
echo "Version: $VERSION"

# Ensure logged in to GHCR
if ! docker info 2>/dev/null | grep -q "Registry.*ghcr.io"; then
    echo "ERROR: Not logged in to GHCR. Run:"
    echo "  echo YOUR_TOKEN | docker login ghcr.io -u $REPO_OWNER --password-stdin"
    exit 1
fi

cd /home/ubuntu/proxy-stack

# Build and tag images
docker compose build

# Tag for GHCR
docker tag proxy-stack-ag-tools-ls ghcr.io/$REPO_OWNER/ag-tools-ls:$VERSION
docker tag proxy-stack-ag-proxy-ai ghcr.io/$REPO_OWNER/ag-proxy-ai:$VERSION
docker tag proxy-stack-billing-proxy ghcr.io/$REPO_OWNER/billing-proxy:$VERSION

# Push to GHCR
docker push ghcr.io/$REPO_OWNER/ag-tools-ls:$VERSION
docker push ghcr.io/$REPO_OWNER/ag-proxy-ai:$VERSION
docker push ghcr.io/$REPO_OWNER/billing-proxy:$VERSION

echo ""
echo "=== IMAGES PUBLISHED ==="
echo "Pull with:"
echo "  docker pull ghcr.io/$REPO_OWNER/ag-tools-ls:$VERSION"
echo "  docker pull ghcr.io/$REPO_OWNER/ag-proxy-ai:$VERSION"
echo "  docker pull ghcr.io/$REPO_OWNER/billing-proxy:$VERSION"

# Update docker-compose to use GHCR images
sed -i "s|build:.*context: ./ag-tools-ls|image: ghcr.io/$REPO_OWNER/ag-tools-ls:$VERSION|" docker-compose.yml
sed -i "s|build:.*context: ./ag-proxy-ai|image: ghcr.io/$REPO_OWNER/ag-proxy-ai:$VERSION|" docker-compose.yml
sed -i "s|build:.*context: ./billing-proxy|image: ghcr.io/$REPO_OWNER/billing-proxy:$VERSION|" docker-compose.yml

echo ""
echo "docker-compose.yml updated to use GHCR images"
