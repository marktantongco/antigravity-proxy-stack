/**
 * Antigravity Proxy - Cloudflare Worker
 * API Gateway for Anthropic, OpenAI, Gemini
 */

// CORS headers helper
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, x-api-key, anthropic-version',
};

async function handleRequest(request, env) {
  const url = new URL(request.url);
  
  // Handle CORS preflight
  if (request.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }
  
  // Health check
  if (url.pathname === '/health' || url.pathname === '/') {
    return new Response(JSON.stringify({
      status: 'ok',
      service: 'antigravity-proxy',
      timestamp: Date.now()
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
  
  // Route: Anthropic (Claude) - /v1/messages
  if (url.pathname.startsWith('/v1/messages')) {
    const upstream = `https://api.anthropic.com${url.pathname}`;
    const headers = new Headers(request.headers);
    headers.set('Host', 'api.anthropic.com');
    headers.set('x-api-key', env.ANTHROPIC_API_KEY || '');
    headers.set('anthropic-version', '2023-06-01');
    
    headers.delete('cf-connecting-ip');
    headers.delete('x-forwarded-for');
    
    const response = await fetch(upstream, {
      method: request.method,
      headers,
      body: request.body
    });
    
    const responseHeaders = new Headers(response.headers);
    Object.entries(corsHeaders).forEach(([k, v]) => responseHeaders.set(k, v));
    return new Response(response.body, {
      status: response.status,
      headers: responseHeaders
    });
  }
  
  // Route: OpenAI - /v1/chat/completions, /v1/embeddings
  if (url.pathname.startsWith('/v1/chat') || 
      url.pathname.startsWith('/v1/embeddings') ||
      url.pathname.startsWith('/v1/images')) {
    const upstream = `https://api.openai.com${url.pathname}`;
    const headers = new Headers(request.headers);
    headers.set('Host', 'api.openai.com');
    headers.set('Authorization', `Bearer ${env.OPENAI_API_KEY || ''}`);
    
    headers.delete('cf-connecting-ip');
    headers.delete('x-forwarded-for');
    
    const response = await fetch(upstream, {
      method: request.method,
      headers,
      body: request.body
    });
    
    const responseHeaders = new Headers(response.headers);
    Object.entries(corsHeaders).forEach(([k, v]) => responseHeaders.set(k, v));
    return new Response(response.body, {
      status: response.status,
      headers: responseHeaders
    });
  }
  
  // Route: Gemini - /v1beta/
  if (url.pathname.startsWith('/v1beta/')) {
    const upstream = new URL(`https://generativelanguage.googleapis.com${url.pathname}`);
    if (env.GEMINI_API_KEY) {
      upstream.searchParams.set('key', env.GEMINI_API_KEY);
    }
    const headers = new Headers(request.headers);
    headers.set('Host', 'generativelanguage.googleapis.com');
    
    headers.delete('cf-connecting-ip');
    headers.delete('x-forwarded-for');
    
    const response = await fetch(upstream.toString(), {
      method: request.method,
      headers,
      body: request.body
    });
    
    const responseHeaders = new Headers(response.headers);
    Object.entries(corsHeaders).forEach(([k, v]) => responseHeaders.set(k, v));
    return new Response(response.body, {
      status: response.status,
      headers: responseHeaders
    });
  }
  
  // 404 for unknown routes
  return new Response(JSON.stringify({
    error: 'Not found',
    message: 'Supported routes: /v1/messages, /v1/chat/completions, /v1beta/'
  }), { 
    status: 404,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
  });
}

addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request, event.env));
});