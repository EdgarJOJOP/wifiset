// BPNMD - Service Worker（后台保活 + 通知）
// v2.0 - 增强后台保活，修复XBrowser兼容性

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    clients.claim().then(() => {
      return caches.keys().then(keys => {
        return Promise.all(keys.map(k => caches.delete(k)));
      });
    })
  );
});

self.addEventListener('fetch', (e) => {
  if (e.request.method === 'HEAD') {
    e.respondWith(fetch(e.request));
    return;
  }
  e.respondWith(
    fetch(e.request)
      .then(res => {
        if (e.request.url.startsWith(self.location.origin) &&
            !e.request.url.includes('?')) {
          const clone = res.clone();
          caches.open('bpnmd-v1').then(cache => cache.put(e.request, clone));
        }
        return res;
      })
      .catch(() => caches.match(e.request))
  );
});

self.addEventListener('message', (e) => {
  const data = e.data;
  if (data === 'keepalive-ping') {
    self.clients.matchAll().then(clients => {
      clients.forEach(c => c.postMessage('keepalive-pong'));
    });
    return;
  }
  if (data && data.type === 'ping') {
    self.clients.matchAll().then(clients => {
      clients.forEach(c => c.postMessage({ type: 'pong', id: data.id }));
    });
  }
});

self.addEventListener('notificationclick', (e) => {
  e.notification.close();
  e.waitUntil(
    clients.matchAll({ type: 'window' }).then(clist => {
      if (clist.length > 0) return clist[0].focus();
      return clients.openWindow(
        self.location.origin + self.location.pathname.replace('sw.js', 'BPNMD.html')
      );
    })
  );
});

self.addEventListener('periodicsync', (e) => {
  if (e.tag === 'bpnmd-keepalive') {
    e.waitUntil(
      self.clients.matchAll().then(clients => {
        clients.forEach(c => c.postMessage('keepalive-ping'));
      })
    );
  }
});
