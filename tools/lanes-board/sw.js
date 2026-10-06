// The Project Manager's service worker, served at /sw.js so it covers every
// page: it shows each lock-screen notification the board pushes (push.mjs
// pushMessage: title, body, tag, url) and, on a tap, opens what it's about.
// A notification with the same tag (one per session) replaces the older one.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));

self.addEventListener('push', (e) => {
  let m = {};
  try { m = e.data ? e.data.json() : {}; } catch { m = { body: e.data ? e.data.text() : '' }; }
  // iOS requires every push to show a notification.
  e.waitUntil(self.registration.showNotification(m.title || 'Project Manager', {
    body: m.body || '',
    tag: m.tag || undefined,
    renotify: !!m.tag,
    icon: '/icon.png',
    badge: '/icon.png',
    data: { url: m.url || '/m' },
  }));
});

// An open page is told where to go (it marks the record read and opens it);
// with none open, the app opens at that address.
self.addEventListener('notificationclick', (e) => {
  e.notification.close();
  const url = new URL(e.notification.data?.url || '/m', self.location.origin).href;
  e.waitUntil((async () => {
    const pages = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    const page = pages.find((c) => new URL(c.url).origin === self.location.origin);
    if (page) {
      page.postMessage({ type: 'open', url });
      return page.focus();
    }
    return self.clients.openWindow(url);
  })());
});
