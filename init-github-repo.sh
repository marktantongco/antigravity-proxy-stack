#!/bin/bash
# Initialize GitHub repository for this project

set -e

REPO_NAME="${1:-antigravity-proxy-stack}"
GITHUB_USER="${2:-}"

echo "=== INITIALIZING GITHUB REPO: $REPO_NAME ==="

cd /home/ubuntu/proxy-stack

# Initialize git
git init
git add .

# Create .gitignore
cat > .gitignore << 'GITIGNORE'
# Environment files with secrets
.env
.env.local
.env.production

# SSL certificates
nginx/ssl/*.pem
nginx/ssl/*.key
nginx/ssl/*.crt

# Database files
*.db
*.sqlite
*.sqlite3

# Logs
logs/
*.log

# Node modules
node_modules/

# Rust build artifacts
target/
Cargo.lock

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db
GITIGNORE

git add .gitignore

git commit -m "Initial commit: Antigravity Proxy Stack for Ubuntu 24.04

Complete multi-layered proxy architecture including:
- Docker Compose orchestration
- Nginx reverse proxy with SSL
- AG Tools LS (Rust proxy bridge)
- AG Proxy AI (OpenAI/Anthropic/Gemini gateway)
- Billing proxy with Redis rate limiting
- OpenCode code generation backend
- 9router network routing
- Cursor IDE integration
- claw-code.codes bridging
- Systemd service files
- IPTables firewall rules
- Health checks and recovery scripts

Architecture: Tiered proxy stack (Network -> Reverse Proxy -> AI API -> Billing -> Orchestration)
Target: Ubuntu 22.04/24.04 LTS bare-metal or VM"

# Create GitHub repo via CLI (if gh is installed)
if command -v gh &> /dev/null; then
    if [ -z "$GITHUB_USER" ]; then
        GITHUB_USER=$(gh api user -q .login)
    fi

    gh repo create "$REPO_NAME"         --public         --description "Multi-layered proxy stack for Antigravity ecosystem on Ubuntu"         --source=.         --remote=origin         --push

    echo ""
    echo "=== REPO CREATED ==="
    echo "URL: https://github.com/$GITHUB_USER/$REPO_NAME"
else
    echo ""
    echo "=== MANUAL STEPS ==="
    echo "1. Create repo at: https://github.com/new"
    echo "2. Name: $REPO_NAME"
    echo "3. Run:"
    echo "   git remote add origin https://github.com/YOUR_USER/$REPO_NAME.git"
    echo "   git branch -M main"
    echo "   git push -u origin main"
fi
