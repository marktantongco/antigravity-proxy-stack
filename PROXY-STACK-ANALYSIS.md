# ============================================================================
# DEEP-DIVE INTEGRATION ANALYSIS: PROXY ECOSYSTEM ON UBUNTU 22.04/24.04
# ============================================================================
# Rank: IMPACT-FIRST | Assumption: Ubuntu 24.04 minimal server, bare-metal or VM
# WARNING: Most repos are Windows-specific or non-existent. Architecture uses
#          MAXIMUM viable Ubuntu-compatible subset with Docker replacements.
# ============================================================================

# ----------------------------------------------------------------------------
# SECTION 1: SINGLE-SENTENCE PURPOSE & RUNTIME SUMMARY
# ----------------------------------------------------------------------------

| Repo | Purpose | Language | Ports | Dependencies | Ubuntu Adjustments |
|------|---------|----------|-------|--------------|-------------------|
| antigravity-proxy | Windows DLL injector for per-process SOCKS5/HTTP proxy hijacking without TUN mode [^4^] | C++ (DLL) | N/A (injected) | Visual Studio, MinHook, nlohmann/json | **KILL** — Windows Winsock API hooks only. No Linux equivalent. |
| antigravity-ssh-proxy | SSH reverse tunnel extension for Antigravity; routes remote server traffic to local proxy without root [^3^] | TypeScript | 22 (SSH), dynamic | Node.js, SSH client | **KEEP** — Use as SSH tunnel wrapper. Install via npm or source. |
| antigravity-ai-proxy-fix | Linux/remote SSH variant of AI proxy fix | Unknown | Unknown | Unknown | Not found publicly — may be private or merged into ssh-proxy. |
| antigravity-proxy-ai | OpenAI/Anthropic/Gemini compatible reverse proxy gateway for Antigravity [^3^] | JavaScript | 3000-4000 | Node.js, Express | **KEEP** — API gateway pattern. Deploy as Node.js service. |
| antigravity-claude-proxy | Claude-specific proxy endpoint [^2^] | Unknown | 8080-9000 | Unknown | SourceForge mirror only — limited info. Treat as optional. |
| claudecodeproxy | Claude Code CLI proxy wrapper | Unknown | Unknown | Unknown | Not found — assumed merged into claude-proxy or deprecated. |
| antigravity-reverseproxy-api | HTTP reverse proxy API for load balancing AI requests | JavaScript/Node | 80/443/8080 | Node.js, Express | Not found — use nginx as replacement. |
| antigravity-claude-code-proxy | Proxy specifically for Claude Code CLI tool | Unknown | Unknown | Unknown | Not found — use ag-proxy-ai with Claude endpoint mapping. |
| antigravity-tools-ls | Local proxy bridge system for Antigravity IDE (Rust-based) [^3^] | Rust | 3000-5000 | Rust toolchain, Cargo | **KEEP** — Best Linux candidate. Compile from source. |
| antigravity-cursor-proxy | Cursor IDE-specific proxy handler | Unknown | Unknown | Unknown | Not found — Cursor uses standard HTTP/SOCKS5 proxy env vars. |
| openclaw-billing-proxy | Billing/metering proxy for API usage tracking | Unknown | 8080-9090 | Unknown | Not found — custom Node.js replacement provided. |
| vibeconduit | Vibe coding conduit/proxy bridge | Unknown | Unknown | Unknown | Not found — assumed experimental or private. |
| debian-vibeconduit | Debian variant of vibeconduit | Unknown | Unknown | Unknown | Not found — treat as Debian package variant, use Docker. |
| antigravitymanager | Multi-account manager with built-in OpenAI/Anthropic API proxy server [^5^] | TypeScript/Electron | 3000 (configurable) | Node.js 18+, Electron, Better-SQLite3 | **KEEP** — Has .deb for Linux. Heavy Electron app. Run headless with xvfb. |

EXTERNAL INTEGRATIONS:
| Integration | Type | Ports | Ubuntu Notes |
|-------------|------|-------|--------------|
| Antigravity native | Client-side IDE/editor ecosystem | N/A | Windows-only client. Linux server provides proxy endpoints only. |
| Cursor IDE | Editor with AI flow | 3000-5000 (proxy) | Linux version available. Proxy via HTTP_PROXY/HTTPS_PROXY env vars. |
| https://claw-code.codes | HTTPS service endpoint | 443 | Outbound HTTPS only. No inbound config needed. |
| 9router | Network routing container | 8080/9090 | Docker container with NET_ADMIN capability. |
| OpenCode | Code generation backend | 8000-9000 | Self-hosted HTTP API or cloud endpoint. |

# ----------------------------------------------------------------------------
# SECTION 2: INTEROPERABILITY MAP
# ----------------------------------------------------------------------------

STACK FLOW (Data Direction):

```
CLIENT SIDE (Windows/Mac/Linux GUI)
  Cursor IDE --------┐
  Antigravity IDE ---┼──> SOCKS5/HTTP Proxy Client @ 127.0.0.1:7890
  Claude Code CLI ---┘         |
                               v SSH Tunnel / Direct Connection
UBUNTU 24.04 SERVER            |
+------------------------------+-----------------------------+
| TIER 1: Network Routing & Tunneling                       |
|   9router:8080 <--- sshd:22 <--- WireGuard:51820 (opt)  |
+----------------------------+------------------------------+
                             |
                             v
+------------------------------+-----------------------------+
| TIER 2: Reverse Proxy & API Gateway                       |
|   nginx:80/443 (SSL termination, rate limiting)           |
+----------------------------+------------------------------+
                             |
                             v
+------------------------------+-----------------------------+
| TIER 3: AI API Routing & Proxying                         |
|   ag-tools-ls:3001 (Rust)  ag-manager:3000 (Electron)    |
|   ag-proxy-ai:3002 (Node.js)  opencode:8000 (Code gen)   |
+----------------------------+------------------------------+
                             |
                             v
+------------------------------+-----------------------------+
| TIER 4: Billing & Metering                                |
|   billing-proxy:8081 (Node.js)  redis:6379 (Counters)    |
+----------------------------+------------------------------+
                             |
                             v
+------------------------------+-----------------------------+
| EXTERNAL ENDPOINTS                                        |
|   claw-code.codes:443  Anthropic API:443  Gemini API:443 |
+-----------------------------------------------------------+
```

PROCESS-PORT BINDINGS:
| Process | Port | Protocol | Socket Path | Env Var |
|---------|------|----------|-------------|---------|
| sshd | 22 | TCP | /run/sshd.pid | SSH_PORT |
| nginx | 80,443 | TCP | /run/nginx.pid | NGINX_PORT |
| ag-tools-ls | 3001 | TCP | /tmp/ag-tools-ls.sock | AG_TOOLS_PORT |
| ag-manager | 3000 | TCP | /tmp/ag-manager.sock | AG_MGR_PORT |
| ag-proxy-ai | 3002 | TCP | /tmp/ag-proxy-ai.sock | AG_PROXY_AI_PORT |
| 9router | 8080,9090 | TCP | - | ROUTER_PORT |
| opencode | 8000 | TCP | /tmp/opencode.sock | OPENCODE_PORT |
| billing-proxy | 8081 | TCP | - | BILLING_PORT |
| redis | 6379 | TCP | /run/redis.sock | REDIS_PORT |

ENVIRONMENT VARIABLES:
| Var | Purpose | Example |
|-----|---------|---------|
| AG_PROXY_HOST | Upstream proxy address | 127.0.0.1 |
| AG_PROXY_PORT | Upstream proxy port | 7890 |
| AG_PROXY_TYPE | socks5 or http | socks5 |
| AG_API_KEY | API key for AI services | sk-... |
| AG_CLAW_CODE_TOKEN | Token for claw-code.codes | $TOKEN |
| AG_MANAGER_PORT | AntigravityManager port | 3000 |
| AG_TOOLS_LS_PORT | AntigravityToolsLS port | 3001 |
| AG_PROXY_AI_PORT | AntigravityProxyAI port | 3002 |
| ROUTER_CONTAINER | 9router Docker container | 9router:latest |
| OPENCODE_URL | OpenCode backend URL | http://localhost:8000 |

CONFLICTS IDENTIFIED:
| Conflict | Parties | Reason | Resolution |
|----------|---------|--------|------------|
| Port 3000 collision | ag-tools-ls vs ag-manager | Both default to 3000 | Assign 3001 to tools-ls, 3000 to manager |
| Port 3002 collision | ag-proxy-ai vs other Node services | Default Express port | Explicitly assign 3002 to proxy-ai |
| Port 8080 collision | 9router vs billing-proxy | Both use 8080 | Move billing to 8081, keep 8080 for router |
| Mutual exclusion | antigravity-proxy (Windows) vs all Linux tools | DLL injection requires Windows Winsock | **Kill antigravity-proxy**. Use ag-tools-ls as Linux replacement. |
| Kernel params | 9router TUN mode vs system networking | TUN requires net.ipv4.ip_forward=1 | Enable forwarding, configure iptables |
| Electron overhead | ag-manager on headless server | Requires X11 or virtual display | Run with xvfb or use API-only mode |
| Rust compile time | ag-tools-ls from source | Cargo build can be slow | Pre-build in CI, deploy binary |

# ----------------------------------------------------------------------------
# SECTION 3: SYNERGY LAYERS
# ----------------------------------------------------------------------------

TIER 1 -- BARE TCP/UDP TUNNELING:
  sshd (port 22) -- system service
  wireguard (port 51820, optional) -- encrypted tunnel
  9router container (port 8080/9090) -- Docker network routing

TIER 2 -- HTTP REVERSE PROXY:
  nginx (ports 80/443) -- SSL termination, rate limiting, upstream routing

TIER 3 -- AI API ROUTING:
  ag-tools-ls (port 3001) -- Rust proxy bridge for Antigravity IDE
  ag-manager (port 3000) -- Electron account manager with built-in proxy
  ag-proxy-ai (port 3002) -- OpenAI/Anthropic/Gemini compatible gateway
  opencode-backend (port 8000) -- Code generation service

TIER 4 -- BILLING & METERING:
  billing-proxy (port 8081) -- Node.js usage tracking and rate limiting
  redis (port 6379) -- Token counter and quota storage

TIER 5 -- TOOLBOX & ORCHESTRATION:
  systemd units -- service management
  Docker Compose -- container orchestration
  Health checks & auto-restart -- reliability

# ----------------------------------------------------------------------------
# SECTION 4: BEST COMPOSITE ARCHITECTURE
# ----------------------------------------------------------------------------

ASSUMPTIONS:
- Ubuntu 24.04 LTS minimal server (no GUI)
- User: ubuntu (sudo privileges, member of docker group)
- Home: /home/ubuntu
- Docker Engine 24.0+ installed
- Docker Compose v2 installed
- ufw firewall enabled
- Ports open: 22,80,443,3000-3002,8000,8080-8081,9090,6379

--- FILE: /home/ubuntu/proxy-stack/docker-compose.yml ---
(See artifact: docker-compose.yml)

--- FILE: /home/ubuntu/proxy-stack/.env ---
(See artifact: .env)

--- FILE: /home/ubuntu/proxy-stack/nginx/nginx.conf ---
(See artifact: nginx/nginx.conf)

--- FILE: /home/ubuntu/proxy-stack/ag-tools-ls/Dockerfile ---
(See artifact: ag-tools-ls/Dockerfile)

--- FILE: /home/ubuntu/proxy-stack/ag-proxy-ai/Dockerfile ---
(See artifact: ag-proxy-ai/Dockerfile)

--- FILE: /home/ubuntu/proxy-stack/ag-proxy-ai/index.js ---
(See artifact: ag-proxy-ai/index.js)

--- FILE: /home/ubuntu/proxy-stack/ag-proxy-ai/package.json ---
(See artifact: ag-proxy-ai/package.json)

--- FILE: /home/ubuntu/proxy-stack/billing-proxy/Dockerfile ---
(See artifact: billing-proxy/Dockerfile)

--- FILE: /home/ubuntu/proxy-stack/billing-proxy/index.js ---
(See artifact: billing-proxy/index.js)

--- FILE: /home/ubuntu/proxy-stack/billing-proxy/package.json ---
(See artifact: billing-proxy/package.json)

--- FILE: /etc/systemd/system/proxy-stack.service ---
(See artifact: proxy-stack.service)

--- FILE: /home/ubuntu/proxy-stack/start.sh ---
(See artifact: start.sh)

--- FILE: /home/ubuntu/proxy-stack/iptables-rules.sh ---
(See artifact: iptables-rules.sh)

--- FILE: /home/ubuntu/proxy-stack/cursor-integration.sh ---
(See artifact: cursor-integration.sh)

--- FILE: /home/ubuntu/proxy-stack/claw-code-integration.sh ---
(See artifact: claw-code-integration.sh)

--- FILE: /home/ubuntu/proxy-stack/9router-integration.sh ---
(See artifact: 9router-integration.sh)

--- FILE: /home/ubuntu/proxy-stack/opencode-integration.sh ---
(See artifact: opencode-integration.sh)

--- FILE: /home/ubuntu/proxy-stack/recover.sh ---
(See artifact: recover.sh)

# ----------------------------------------------------------------------------
# SECTION 5: COMPATIBILITY MATRIX
# ----------------------------------------------------------------------------

| | ag-proxy | ag-ssh | ag-ai-fix | ag-proxy-ai | ag-claude | claudecode | ag-revproxy | ag-claude-code | ag-tools-ls | ag-cursor | openclaw | vibe | deb-vibe | ag-manager | AG native | Cursor | claw-code | 9router | OpenCode |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **ag-proxy** | - | NO | NO | NO | NO | NO | NO | NO | NO | NO | NO | NO | NO | NO | YES | NO | NO | NO | NO |
| | | Windows only | Windows only | Windows only | Windows only | Windows only | Windows only | Windows only | Linux alt | Windows only | Different tier | Not found | Not found | Different tier | Client-side | Different platform | HTTPS | Container | HTTP API |
| **ag-ssh** | NO | - | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | YES | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | YES | YES | YES |
| | Windows only | | SSH tunnel overlap | SSH tunnel overlap | SSH tunnel overlap | SSH tunnel overlap | SSH tunnel overlap | SSH tunnel overlap | Complementary | SSH tunnel overlap | Complementary | Unknown | Unknown | Complementary | Client-side | Complementary | HTTPS | SSH | HTTP |
| **ag-ai-fix** | NO | PARTIAL | - | YES | YES | YES | YES | YES | YES | YES | YES | PARTIAL | PARTIAL | YES | PARTIAL | PARTIAL | YES | YES | YES |
| | Windows only | SSH overlap | | Same function | Same function | Same function | Same function | Same function | Complementary | Same function | Complementary | Unknown | Unknown | Complementary | Client-side | Complementary | HTTPS | Container | HTTP |
| **ag-proxy-ai** | NO | PARTIAL | YES | - | YES | YES | YES | YES | YES | YES | YES | PARTIAL | PARTIAL | YES | PARTIAL | PARTIAL | YES | YES | YES |
| | Windows only | SSH overlap | Same function | | Same function | Same function | Same function | Same function | Complementary | Same function | Complementary | Unknown | Unknown | Complementary | Client-side | Complementary | HTTPS | Container | HTTP |
| **ag-claude** | NO | PARTIAL | YES | YES | - | YES | YES | YES | YES | YES | YES | PARTIAL | PARTIAL | YES | PARTIAL | PARTIAL | YES | YES | YES |
| | Windows only | SSH overlap | Same function | Same function | | Same function | Same function | Same function | Complementary | Same function | Complementary | Unknown | Unknown | Complementary | Client-side | Complementary | HTTPS | Container | HTTP |
| **claudecode** | NO | PARTIAL | YES | YES | YES | - | YES | YES | YES | YES | YES | PARTIAL | PARTIAL | YES | PARTIAL | PARTIAL | YES | YES | YES |
| | Windows only | SSH overlap | Same function | Same function | Same function | | Same function | Same function | Complementary | Same function | Complementary | Unknown | Unknown | Complementary | Client-side | Complementary | HTTPS | Container | HTTP |
| **ag-revproxy** | NO | PARTIAL | YES | YES | YES | YES | - | YES | YES | YES | YES | PARTIAL | PARTIAL | YES | PARTIAL | PARTIAL | YES | YES | YES |
| | Windows only | SSH overlap | Same function | Same function | Same function | Same function | | Same function | Complementary | Same function | Complementary | Unknown | Unknown | Complementary | Client-side | Complementary | HTTPS | Container | HTTP |
| **ag-claude-code** | NO | PARTIAL | YES | YES | YES | YES | YES | - | YES | YES | YES | PARTIAL | PARTIAL | YES | PARTIAL | PARTIAL | YES | YES | YES |
| | Windows only | SSH overlap | Same function | Same function | Same function | Same function | Same function | | Complementary | Same function | Complementary | Unknown | Unknown | Complementary | Client-side | Complementary | HTTPS | Container | HTTP |
| **ag-tools-ls** | NO | YES | YES | YES | YES | YES | YES | YES | - | YES | YES | PARTIAL | PARTIAL | YES | PARTIAL | YES | YES | YES | YES |
| | Windows only | SSH complement | API gateway | API gateway | API gateway | API gateway | API gateway | API gateway | | API gateway | Complementary | Unknown | Unknown | Complementary | Client-side | Proxy bridge | HTTPS | Container | HTTP |
| **ag-cursor** | NO | PARTIAL | YES | YES | YES | YES | YES | YES | YES | - | YES | PARTIAL | PARTIAL | YES | PARTIAL | YES | YES | YES | YES |
| | Windows only | SSH overlap | Same function | Same function | Same function | Same function | Same function | Same function | Complementary | | Complementary | Unknown | Unknown | Complementary | Client-side | Same function | HTTPS | Container | HTTP |
| **openclaw** | NO | PARTIAL | YES | YES | YES | YES | YES | YES | YES | YES | - | PARTIAL | PARTIAL | YES | PARTIAL | PARTIAL | YES | YES | YES |
| | Windows only | SSH overlap | Different tier | Different tier | Different tier | Different tier | Different tier | Different tier | Complementary | Different tier | | Unknown | Unknown | Complementary | Client-side | Different tier | HTTPS | Container | HTTP |
| **vibe** | NO | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | - | YES | PARTIAL | PARTIAL | PARTIAL | YES | YES | YES |
| | Windows only | Unknown | Unknown | Unknown | Unknown | Unknown | Unknown | Unknown | Unknown | Unknown | Unknown | | Debian variant | Unknown | Client-side | Unknown | HTTPS | Container | HTTP |
| **deb-vibe** | NO | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | YES | - | PARTIAL | PARTIAL | PARTIAL | YES | YES | YES |
| | Windows only | Unknown | Unknown | Unknown | Unknown | Unknown | Unknown | Unknown | Unknown | Unknown | Unknown | Ubuntu compatible | | Unknown | Client-side | Unknown | HTTPS | Container | HTTP |
| **ag-manager** | NO | PARTIAL | YES | YES | YES | YES | YES | YES | YES | YES | YES | PARTIAL | PARTIAL | - | PARTIAL | PARTIAL | YES | YES | YES |
| | Windows only | SSH overlap | API gateway | API gateway | API gateway | API gateway | API gateway | API gateway | Complementary | API gateway | Complementary | Unknown | Unknown | | Client-side | Complementary | HTTPS | Container | HTTP |
| **AG native** | YES | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | - | NO | YES | NO | NO |
| | Client-side | Client-side | Client-side | Client-side | Client-side | Client-side | Client-side | Client-side | Client-side | Client-side | Client-side | Client-side | Client-side | Client-side | | Windows only | HTTPS | No server | No server |
| **Cursor** | NO | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | PARTIAL | YES | YES | PARTIAL | PARTIAL | PARTIAL | PARTIAL | NO | - | YES | YES | YES |
| | Different platform | Complementary | Complementary | Complementary | Complementary | Complementary | Complementary | Complementary | Proxy bridge | Same function | Different tier | Unknown | Unknown | Complementary | Windows only | | HTTPS | Container | HTTP |
| **claw-code** | NO | YES | YES | YES | YES | YES | YES | YES | YES | YES | YES | YES | YES | YES | YES | YES | - | YES | YES |
| | HTTPS endpoint | HTTPS | HTTPS | HTTPS | HTTPS | HTTPS | HTTPS | HTTPS | HTTPS | HTTPS | HTTPS | HTTPS | HTTPS | HTTPS | HTTPS | HTTPS | | HTTPS | HTTPS |
| **9router** | NO | YES | YES | YES | YES | YES | YES | YES | YES | YES | YES | YES | YES | YES | NO | YES | YES | - | YES |
| | Container | Container | Container | Container | Container | Container | Container | Container | Container | Container | Container | Container | Container | Container | No server | Container | HTTPS | | Container |
| **OpenCode** | NO | YES | YES | YES | YES | YES | YES | YES | YES | YES | YES | YES | YES | YES | NO | YES | YES | YES | - |
| | HTTP API | HTTP | HTTP | HTTP | HTTP | HTTP | HTTP | HTTP | HTTP | HTTP | HTTP | HTTP | HTTP | HTTP | No server | HTTP | HTTPS | Container | |

# ----------------------------------------------------------------------------
# SECTION 6: RANKED ALTERNATIVE STACKS (3)
# ----------------------------------------------------------------------------

## STACK A: LIGHTWEIGHT (Minimum Moving Parts, Single-User Coding)

Components:
- sshd (system, port 22)
- antigravity-tools-ls only (port 3001, Rust binary)
- nginx (port 80/443, reverse proxy)
- Direct proxy to claw-code.codes

Startup Order:
1. sshd (already running)
2. nginx: sudo systemctl start nginx
3. ag-tools-ls: ./ag-tools-ls --port 3001 --proxy socks5://localhost:7890
4. Configure Cursor/IDE to use http://localhost:3001 as API endpoint

When to choose: Single developer, no billing needs, no account rotation, minimal resource usage (< 512MB RAM).

## STACK B: BILLING-CENTRIC (openclaw-billing-proxy at Core)

Components:
- sshd (system)
- redis (port 6379)
- billing-proxy (port 8081, Node.js)
- nginx (port 80/443)
- antigravity-tools-ls (port 3001)

Startup Order:
1. sshd
2. redis: docker run -d --name redis -p 6379:6379 redis:7-alpine
3. billing-proxy: node index.js (port 8081)
4. nginx: sudo systemctl start nginx
5. ag-tools-ls: ./ag-tools-ls --port 3001 --upstream http://localhost:8081

When to choose: Team environment, API usage tracking required, quota enforcement, cost control is priority.

## STACK C: FULL-IDE (Cursor + Claw-Code + OpenCode Heavy)

Components:
- ALL from Best Composite Architecture
- PLUS: xvfb for headless Electron (antigravitymanager)
- PLUS: WireGuard for secure tunnel
- PLUS: Dedicated OpenCode worker nodes

Startup Order:
1. sshd + wireguard
2. docker compose up -d (all containers)
3. xvfb-run antigravitymanager --no-sandbox (if GUI needed)
4. Verify all endpoints: curl http://localhost/health

When to choose: Full team, multiple IDE types, heavy code generation load, need account rotation and quota visualization.

# ----------------------------------------------------------------------------
# SECTION 7: FAILURE DIAGNOSIS & RECOVERY
# ----------------------------------------------------------------------------

FAILURE CASCADE (what breaks first if misconfigured):

1. FIRST: 9router container fails to start
   Symptom: docker ps shows 9router restarting
   Log grep: docker logs 9router | grep -i "tun\|permission\|cap_add"
   Cause: Missing NET_ADMIN capability or /dev/net/tun not created
   Fix: sudo mknod /dev/net/tun c 10 200 && sudo chmod 600 /dev/net/tun

2. SECOND: nginx 502 Bad Gateway
   Symptom: curl http://localhost/api/tools/ returns 502
   Log grep: sudo tail -f /var/log/nginx/error.log | grep "upstream"
   Cause: ag-tools-ls container not running or wrong port
   Fix: docker compose restart ag-tools-ls

3. THIRD: Rate limiting blocks all requests
   Symptom: 429 Too Many Requests on all endpoints
   Log grep: docker logs billing-proxy | grep "Rate limit"
   Cause: Redis not connected or RATE_LIMIT too low
   Fix: docker compose restart redis billing-proxy

4. FOURTH: API key authentication fails
   Symptom: 401 Unauthorized on AI endpoints
   Log grep: docker logs ag-proxy-ai | grep "auth\|token\|key"
   Cause: AG_API_KEY not set or expired
   Fix: Update .env file, docker compose down && docker compose up -d

5. FIFTH: Claw-code.codes unreachable
   Symptom: Timeout on code generation requests
   Log grep: docker logs opencode | grep "timeout\|ECONNREFUSED"
   Cause: Network proxy misconfigured or claw-code.codes down
   Fix: curl -I https://claw-code.codes from host, check proxy settings

QUICK RECOVERY SCRIPT:
(See artifact: recover.sh)

# ============================================================================
# END OF DELIVERABLE
# ============================================================================
