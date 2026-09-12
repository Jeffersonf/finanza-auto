// Cloudflare Worker for Finanza Auto with Static Assets & API Sync
export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    if (url.pathname === '/api/sync' || url.pathname === '/api/sync/') {
      if (request.method === 'POST') {
        try {
          const body = await request.json();
          const stateData = JSON.stringify({
            updatedAt: new Date().toISOString(),
            data: body.data || body
          });

          if (env.FINANZA_KV) {
            await env.FINANZA_KV.put('finanza_auto_state', stateData);
          } else {
            globalThis.__FINANZA_STATE_CACHE__ = stateData;
          }

          return new Response(JSON.stringify({
            success: true,
            updatedAt: new Date().toISOString(),
            message: 'Estado sincronizado com sucesso no Cloudflare.'
          }), {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        } catch (err) {
          return new Response(JSON.stringify({
            success: false,
            error: err.message || 'Erro ao processar JSON de sincronizacao'
          }), {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }
      }

      if (request.method === 'GET') {
        let stored = null;
        if (env.FINANZA_KV) {
          stored = await env.FINANZA_KV.get('finanza_auto_state');
        } else {
          stored = globalThis.__FINANZA_STATE_CACHE__ || null;
        }

        if (stored) {
          return new Response(stored, {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        } else {
          return new Response(JSON.stringify({
            empty: true,
            message: 'Nenhum dado na nuvem ainda. Faca o primeiro envio pelo app ou web.'
          }), {
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          });
        }
      }
    }

    if (env.ASSETS) {
      return env.ASSETS.fetch(request);
    }

    return new Response('Finanza Auto Cloudflare Worker Ready', {
      headers: { 'Content-Type': 'text/plain' }
    });
  }
};
