const express = require('express');
const Redis = require('ioredis');
const axios = require('axios');
const app = express();

const redis = new Redis({
    host: process.env.REDIS_HOST || 'redis',
    port: parseInt(process.env.REDIS_PORT) || 6379,
    retryStrategy: (times) => Math.min(times * 50, 2000)
});

const PORT = process.env.PORT || 8081;
const RATE_LIMIT = parseInt(process.env.RATE_LIMIT) || 1000;
const WINDOW_MS = parseInt(process.env.WINDOW_MS) || 3600000;
const AG_PROXY_AI_URL = process.env.AG_PROXY_AI_URL || 'http://ag-proxy-ai:3002';

// Vercel integration
const VERCEL_TOKEN = process.env.VERCEL_TOKEN || '';
const VERCEL_AI_GATEWAY_API_KEY = process.env.VERCEL_AI_GATEWAY_API_KEY || '';

app.use(express.json());

// Health check
app.get('/health', (req, res) => {
    res.status(200).json({ 
        status: 'ok', 
        service: 'billing-proxy', 
        port: PORT,
        vercel: VERCEL_TOKEN ? 'connected' : 'not connected'
    });
});

// Check rate limit for API key
async function checkLimit(apiKey) {
    const key = `billing:${apiKey}`;
    const pipeline = redis.pipeline();
    pipeline.incr(key);
    pipeline.pttl(key);
    const results = await pipeline.exec();
    const current = results[0][1];
    let ttl = results[1][1];

    if (current === 1 || ttl === -1) {
        await redis.pexpire(key, WINDOW_MS);
        ttl = WINDOW_MS;
    }

    return {
        allowed: current <= RATE_LIMIT,
        remaining: Math.max(0, RATE_LIMIT - current),
        resetIn: ttl,
        used: current
    };
}

// Middleware: rate limiting
app.use(async (req, res, next) => {
    const apiKey = req.headers['x-api-key'] || req.headers['authorization']?.replace('Bearer ', '') || 'default';
    const limit = await checkLimit(apiKey);

    res.setHeader('X-RateLimit-Limit', RATE_LIMIT);
    res.setHeader('X-RateLimit-Remaining', limit.remaining);
    res.setHeader('X-RateLimit-Reset', limit.resetIn);

    if (!limit.allowed) {
        return res.status(429).json({
            error: 'Rate limit exceeded',
            retryAfter: Math.ceil(limit.resetIn / 1000),
            limit: RATE_LIMIT,
            used: limit.used
        });
    }

    req.billingInfo = limit;
    next();
});

// Get usage for API key
app.get('/api/billing/usage', async (req, res) => {
    const apiKey = req.headers['x-api-key'] || 'default';
    const used = await redis.get(`billing:${apiKey}`) || '0';
    const tokens = await redis.get(`billing:tokens:${apiKey}`) || '0';
    const requests = await redis.get(`billing:requests:${apiKey}`) || '0';
    const vercelUsage = await redis.get(`billing:vercel:${apiKey}`) || '0';

    res.json({
        apiKey: apiKey.substring(0, 8) + '...',
        used: parseInt(used),
        limit: RATE_LIMIT,
        tokensUsed: parseInt(tokens),
        totalRequests: parseInt(requests),
        vercelRequests: parseInt(vercelUsage),
        windowMs: WINDOW_MS
    });
});

// Track usage (called by upstream services)
app.post('/api/billing/track', async (req, res) => {
    const { apiKey, tokens, model, endpoint, provider } = req.body;
    const key = apiKey || 'default';

    const pipeline = redis.pipeline();
    pipeline.incrby(`billing:tokens:${key}`, tokens || 1);
    pipeline.incr(`billing:requests:${key}`);
    pipeline.incr(`billing:models:${model || 'unknown'}`);
    pipeline.incr(`billing:endpoints:${endpoint || 'unknown'}`);

    // Track Vercel-specific usage
    if (provider === 'vercel-gateway') {
        pipeline.incr(`billing:vercel:${key}`);
    }

    pipeline.expire(`billing:tokens:${key}`, 86400 * 30);
    pipeline.expire(`billing:requests:${key}`, 86400 * 30);

    await pipeline.exec();
    res.json({ tracked: true, timestamp: new Date().toISOString() });
});

// Vercel deployment status (if token available)
app.get('/api/billing/vercel/status', async (req, res) => {
    if (!VERCEL_TOKEN) {
        return res.status(503).json({ error: 'Vercel token not configured' });
    }

    try {
        const response = await axios.get('https://api.vercel.com/v9/user', {
            headers: { Authorization: `Bearer ${VERCEL_TOKEN}` }
        });
        res.json({
            connected: true,
            user: response.data.user?.username || 'unknown',
            gateway: VERCEL_AI_GATEWAY_API_KEY ? 'configured' : 'not configured'
        });
    } catch (error) {
        res.status(502).json({ error: 'Vercel API error', message: error.message });
    }
});

// Proxy to AG Proxy AI with billing tracking
app.post('/api/billing/proxy/*', async (req, res) => {
    try {
        const targetPath = req.params[0];
        const startTime = Date.now();

        const response = await axios({
            method: req.method,
            url: `${AG_PROXY_AI_URL}/${targetPath}`,
            data: req.body,
            headers: {
                ...req.headers,
                host: undefined
            },
            timeout: 120000,
            responseType: req.headers.accept?.includes('event-stream') ? 'stream' : 'json'
        });

        const duration = Date.now() - startTime;

        const apiKey = req.headers['x-api-key'] || 'default';
        const tokenCount = req.body.messages?.reduce((acc, m) => acc + (m.content?.length || 0), 0) || 1;

        await redis.incrby(`billing:tokens:${apiKey}`, tokenCount);
        await redis.incr(`billing:requests:${apiKey}`);

        if (response.headers['content-type']?.includes('event-stream')) {
            res.setHeader('Content-Type', 'text/event-stream');
            response.data.pipe(res);
        } else {
            res.json(response.data);
        }
    } catch (error) {
        console.error('Billing proxy error:', error.message);
        res.status(502).json({ error: 'Upstream error', message: error.message });
    }
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`Billing proxy on port ${PORT}`);
    console.log(`Rate limit: ${RATE_LIMIT} requests per ${WINDOW_MS}ms`);
    console.log(`Vercel integration: ${VERCEL_TOKEN ? 'ENABLED' : 'DISABLED'}`);
});
