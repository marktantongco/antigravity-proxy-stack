# Proxy Stack Setup Checklist

## Phase 1: System Preparation
- [ ] Install Ubuntu 24.04 LTS (minimal server)
- [ ] Create user `ubuntu` with sudo privileges
- [ ] Update system: `sudo apt-get update && sudo apt-get upgrade -y`
- [ ] Install Docker Engine (Option A above)
- [ ] Add user to docker group: `sudo usermod -aG docker ubuntu`
- [ ] Log out and back in (or `newgrp docker`)
- [ ] Verify: `docker run hello-world`

## Phase 2: GitHub Association (Choose One)
### Option A: New Repo
- [ ] Run `init-github-repo.sh my-proxy-stack myusername`
- [ ] Verify repo at `https://github.com/myusername/my-proxy-stack`

### Option B: Fork Existing
- [ ] Fork https://github.com/yuaotian/antigravity-proxy
- [ ] Add proxy-stack files to new branch
- [ ] Submit PR if contributing back

## Phase 3: Deploy Stack
- [ ] Clone/download proxy-stack files to `/home/ubuntu/proxy-stack`
- [ ] Copy `.env.example` to `.env` and fill in real values
- [ ] Run `./start.sh`
- [ ] Verify all services: `./recover.sh`

## Phase 4: Integrations
- [ ] Run `./cursor-integration.sh` for Cursor IDE
- [ ] Run `./claw-code-integration.sh` for claw-code.codes
- [ ] Run `./9router-integration.sh` for network routing
- [ ] Run `./opencode-integration.sh` for code generation

## Phase 5: Production Hardening
- [ ] Replace self-signed SSL cert with real certificate
- [ ] Enable UFW firewall: `sudo ufw enable`
- [ ] Run `./iptables-rules.sh` for advanced firewall rules
- [ ] Install systemd service: `sudo cp proxy-stack.service /etc/systemd/system/`
- [ ] Enable auto-start: `sudo systemctl enable --now proxy-stack`
- [ ] Set up log rotation
- [ ] Configure monitoring (Prometheus/Grafana optional)

## Phase 6: CI/CD (Optional)
- [ ] Set up GitHub Actions for automated builds
- [ ] Configure GHCR publishing
- [ ] Set up automated testing
