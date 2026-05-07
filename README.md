# Antigravity Proxy Stack

API Gateway for multiple AI providers with Cloudflare Workers deployment.

## 🌐 Endpoints

| Service | Endpoint | Status |
|---------|----------|--------|
| **Health** | `https://antigravity-proxy.mark-tantongco.workers.dev/health` | ✅ |
| **Anthropic** | `/v1/messages` | ⚠️ Needs API key |
| **OpenAI** | `/v1/chat/completions` | ⚠️ Needs API key |
| **Gemini** | `/v1beta/*` | ⚠️ Needs API key |
| **Cloudflare AI** | `/ai/run/@cf/meta/llama-3.1-8b-instruct` | ⚠️ Needs enable |

## 🚀 Deployment

Auto-deploys on push to `master` branch via GitHub Actions.

### Manual Deploy
```bash
npm install -g wrangler
wrangler deploy
```

## 🔧 Configuration

### Cloudflare Secrets
```bash
wrangler secret put ANTHROPIC_API_KEY
wrangler secret put OPENAI_API_KEY
wrangler secret put GEMINI_API_KEY
```

### Enable Workers AI
1. Go to Cloudflare Dashboard → Workers → AI
2. Enable Workers AI
3. Bind AI in worker settings

## 📁 Files

- `worker.js` - Cloudflare Worker script
- `wrangler.toml` - Wrangler configuration
- `.github/workflows/deploy.yml` - Auto-deploy workflow

## 🔗 Related

- GitHub: https://github.com/marktantongco/antigravity-proxy-stack
- Cloudflare: https://dash.cloudflare.com