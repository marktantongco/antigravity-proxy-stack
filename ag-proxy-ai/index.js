const express = require('express');
const axios = require('axios');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const app = express();
const PORT = process.env.PORT || 3002;
const PROXY_HOST = process.env.PROXY_HOST || '127.0.0.1';
const PROXY_PORT = process.env.PROXY_PORT || 7890;
const PROXY_TYPE = process.env.PROXY_TYPE || 'socks5';
const API_KEY = process.env.API_KEY || '';
const CLAW_CODE_TOKEN = process.env.CLAW_CODE_TOKEN || '';

// Vercel AI Gateway configuration
const VERCEL_AI_GATEWAY_API_KEY = process.env.VERCEL_AI_GATEWAY_API_KEY || '';
const VERCEL_AI_GATEWAY_URL = process.env.VERCEL_AI_GATEWAY_URL || 'https://ai-gateway.vercel.sh/v1';

app.use(helmet());
app.use(cors());
app.use(morgan('combined'));
app.use(express.json({ limit: '50mb' }));

// Health check
app.get('/health', (req, res) => {
    res.status(200).json({ 
        status: 'ok', 
        service: 'ag-proxy-ai', 
        port: PORT,
        vercelGateway: VERCEL_AI_GATEWAY_API_KEY ? 'configured' : 'not configured'
    });
});

// Unified AI proxy via Vercel AI Gateway (preferred route)
app.post('/v1/chat/completions', async (req, res) => {
    try {
        const { model, messages, stream = false } = req.body;

        // Priority 1: Vercel AI Gateway (unified endpoint for all providers)
        if (VERCEL_AI_GATEWAY_API_KEY) {
            const response = await axios.post(`${VERCEL_AI_GATEWAY_URL}/chat/completions`, req.body, {
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${VERCEL_AI_GATEWAY_API_KEY}`
                },
                timeout: 120000,
                responseType: stream ? 'stream' : 'json'
            });

            if (stream) {
                res.setHeader('Content-Type', 'text/event-stream');
                res.setHeader('Cache-Control', 'no-cache');
                res.setHeader('Connection', 'keep-alive');
                response.data.pipe(res);
            } else {
                res.json(response.data);
            }
            return;
        }

        // Priority 2: Direct provider routing (fallback)
        let targetUrl;
        let headers = { 'Content-Type': 'application/json' };

        if (model && model.startsWith('claude')) {
            targetUrl = 'https://api.anthropic.com/v1/messages';
            headers['x-api-key'] = API_KEY;
            headers['anthropic-version'] = '2023-06-01';
        } else if (model && model.startsWith('gemini')) {
            targetUrl = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${API_KEY}`;
        } else {
            targetUrl = 'https://api.openai.com/v1/chat/completions';
            headers['Authorization'] = `Bearer ${API_KEY}`;
        }

        const response = await axios.post(targetUrl, req.body, {
            headers,
            timeout: 120000,
            responseType: stream ? 'stream' : 'json'
        });

        if (stream) {
            res.setHeader('Content-Type', 'text/event-stream');
            res.setHeader('Cache-Control', 'no-cache');
            res.setHeader('Connection', 'keep-alive');
            response.data.pipe(res);
        } else {
            res.json(response.data);
        }
    } catch (error) {
        console.error('Proxy AI error:', error.message);
        res.status(502).json({ 
            error: 'Bad Gateway', 
            message: error.message,
            service: 'ag-proxy-ai'
        });
    }
});

// Vercel AI Gateway direct passthrough (all endpoints)
app.all('/gateway/*', async (req, res) => {
    try {
        if (!VERCEL_AI_GATEWAY_API_KEY) {
            return res.status(503).json({ error: 'Vercel AI Gateway not configured' });
        }

        const path = req.params[0];
        const response = await axios({
            method: req.method,
            url: `${VERCEL_AI_GATEWAY_URL}/${path}`,
            data: req.body,
            headers: {
                ...req.headers,
                'Authorization': `Bearer ${VERCEL_AI_GATEWAY_API_KEY}`,
                'host': undefined
            },
            timeout: 120000,
            responseType: req.headers.accept?.includes('event-stream') ? 'stream' : 'json'
        });

        if (response.headers['content-type']?.includes('event-stream')) {
            res.setHeader('Content-Type', 'text/event-stream');
            response.data.pipe(res);
        } else {
            res.json(response.data);
        }
    } catch (error) {
        console.error('Vercel Gateway error:', error.message);
        res.status(502).json({ error: 'Gateway Error', message: error.message });
    }
});

// Claw-Code.codes bridge endpoint
app.post('/api/claw-code/generate', async (req, res) => {
    try {
        const response = await axios.post('https://claw-code.codes/api/v1/generate', req.body, {
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${CLAW_CODE_TOKEN}`
            },
            timeout: 300000
        });
        res.json(response.data);
    } catch (error) {
        console.error('Claw-Code error:', error.message);
        res.status(502).json({ 
            error: 'Claw-Code Gateway Error', 
            message: error.message 
        });
    }
});

// Model listing (includes Vercel Gateway models if configured)
app.get('/v1/models', (req, res) => {
    const models = [
        { id: 'gpt-4', object: 'model', provider: 'openai' },
        { id: 'gpt-4-turbo', object: 'model', provider: 'openai' },
        { id: 'claude-3-5-sonnet', object: 'model', provider: 'anthropic' },
        { id: 'claude-3-opus', object: 'model', provider: 'anthropic' },
        { id: 'gemini-pro', object: 'model', provider: 'google' },
        { id: 'gemini-ultra', object: 'model', provider: 'google' }
    ];

    if (VERCEL_AI_GATEWAY_API_KEY) {
        models.push(
            { id: 'vercel-gpt-4', object: 'model', provider: 'vercel-gateway' },
            { id: 'vercel-claude-3-5-sonnet', object: 'model', provider: 'vercel-gateway' }
        );
    }

    res.json({ object: 'list', data: models });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`AG Proxy AI listening on port ${PORT}`);
    console.log(`Upstream proxy: ${PROXY_TYPE}://${PROXY_HOST}:${PROXY_PORT}`);
    console.log(`Vercel AI Gateway: ${VERCEL_AI_GATEWAY_API_KEY ? 'ENABLED' : 'DISABLED'}`);
});
