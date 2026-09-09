/* LianLianKan offline cache.
 * Cache-first for the immutable engine/data payloads (wasm/pck/js/png):
 * once downloaded they load instantly on every later visit. The shell
 * (index.html) is network-first so a new deploy is discovered; the build
 * hash below changes on every deploy, which swaps the cache wholesale and
 * re-prefetches the payloads in the background — the current visit keeps
 * playing from the old cache, the next visit is on the new version.
 */
const BUILD = '__BUILD_HASH__';
const CACHE = `llk-${BUILD}`;
const PAYLOADS = [
  'index.js',
  'index.wasm',
  'index.pck',
  'index.audio.worklet.js',
  'index.icon.png',
  'index.apple-touch-icon.png',
];

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    const scopeUrl = new URL(self.registration.scope);
    await Promise.allSettled(PAYLOADS.map((name) => {
      const url = new URL(name, scopeUrl).href;
      return cache.add(url).catch((err) => console.warn(`[SW] prefetch miss ${name}`, err));
    }));
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) {
      if (key !== CACHE) await caches.delete(key);
    }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== location.origin) return;

  const isShell = url.pathname.endsWith('/') || url.pathname.endsWith('index.html');
  const isPayload = PAYLOADS.some((name) => url.pathname.endsWith(name));
  if (!isShell && !isPayload) return;

  if (isShell) {
    // Network-first: discover new deploys, fall back to cache offline.
    event.respondWith((async () => {
      try {
        const fresh = await fetch(request);
        const cache = await caches.open(CACHE);
        cache.put(request, fresh.clone());
        return fresh;
      } catch (err) {
        return (await caches.match(request)) || Response.error();
      }
    })());
    return;
  }

  // Cache-first payloads: instant repeat visits, refreshed by the next
  // install after a deploy swaps BUILD.
  event.respondWith((async () => {
    const hit = await caches.match(request);
    if (hit) return hit;
    const fresh = await fetch(request);
    const cache = await caches.open(CACHE);
    cache.put(request, fresh.clone());
    return fresh;
  })());
});
