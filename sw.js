// BPNMD - Service Worker（后台保活 + 通知）

self.addEventListener('install',()=>{self.skipWaiting()});
self.addEventListener('activate',(e)=>{e.waitUntil(clients.claim())});

// ★ fetch拦截 — 防止SW被浏览器回收
self.addEventListener('fetch',(e)=>{e.respondWith(fetch(e.request).catch(()=>caches.match(e.request)))});

self.addEventListener('notificationclick',(e)=>{e.notification.close();e.waitUntil(clients.matchAll({type:'window'}).then(clist=>{if(clist.length>0) return clist[0].focus();return clients.openWindow(self.location.origin+self.location.pathname.replace('sw.js','BPNMD.html'))}))});

// ★ 双向保活通信
self.addEventListener('message',(e)=>{if(e.data==='keepalive-ping'){self.clients.matchAll().then(clients=>{clients.forEach(c=>c.postMessage('keepalive-pong'))})}});
