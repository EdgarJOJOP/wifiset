// BPNMD - Service Worker（后台保活 + 通知）
// 让 Android 将浏览器进程视为"前台服务"，大幅减少被杀概率

self.addEventListener('install', () => {
    self.skipWaiting();
});

self.addEventListener('activate', (e) => {
    e.waitUntil(clients.claim());
});

// 接收通知点击事件：切回页面
self.addEventListener('notificationclick', (e) => {
    e.notification.close();
    e.waitUntil(clients.matchAll({type:'window'}).then(clist => {
        if(clist.length>0) return clist[0].focus();
        return clients.openWindow(self.location.origin + self.location.pathname.replace('sw.js','BPNMD.html'));
    }));
});
