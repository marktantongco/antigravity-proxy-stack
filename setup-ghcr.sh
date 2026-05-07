#!/bin/bash
# Configure Docker to use GitHub Container Registry

echo "=== GITHUB CONTAINER REGISTRY SETUP ==="

# Login to GitHub Container Registry
# You need a GitHub Personal Access Token with 'read:packages' scope
# Generate at: https://github.com/settings/tokens

echo "Enter your GitHub username:"
read GITHUB_USER

echo "Enter your GitHub Personal Access Token (hidden):"
read -s GITHUB_TOKEN

echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$GITHUB_USER" --password-stdin

echo ""
echo "=== GHCR CONFIGURED ==="
echo "You can now pull images from ghcr.io/$GITHUB_USER/"
echo ""
echo "Example: docker pull ghcr.io/$GITHUB_USER/antigravity-proxy:latest"
