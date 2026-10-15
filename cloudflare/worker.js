import { Container } from '@cloudflare/containers';

export class ArenaServer extends Container {
  defaultPort = 8080;
  sleepAfter = '10m';
  enableInternet = false;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname === '/health') return Response.json({ status: 'ok', protocol: 'robocon2027-v4' });
    if (url.pathname === '/ws') {
      if (request.headers.get('Upgrade')?.toLowerCase() !== 'websocket') return new Response('WebSocket required', { status: 426 });
      const origin = request.headers.get('Origin');
      if (origin && origin !== url.origin) return new Response('Origin rejected', { status: 403 });
      return env.ARENA.getByName('casual-v2').fetch(request);
    }
    if (url.pathname === '/index.wasm') {
      url.pathname = '/index.wasm.gz';
      const asset = await env.ASSETS.fetch(new Request(url, request));
      if (!asset.ok) return asset;
      const headers = new Headers(asset.headers);
      headers.set('Content-Type', 'application/wasm');
      headers.set('Content-Encoding', 'gzip');
      headers.set('Cache-Control', 'public, max-age=0, must-revalidate');
      return new Response(asset.body, { headers, encodeBody: 'manual' });
    }
    return env.ASSETS.fetch(request);
  },
};
