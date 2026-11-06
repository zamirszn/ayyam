'use strict';

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const payload = typeof event.notification.data === 'string'
    ? event.notification.data
    : '';

  event.waitUntil((async () => {
    const windows = await clients.matchAll({
      type: 'window',
      includeUncontrolled: true,
    });
    if (windows.length > 0) {
      const client = windows[0];
      await client.focus();
      client.postMessage(payload);
      return;
    }

    const appUrl = new URL('../', self.registration.scope);
    appUrl.searchParams.set('notification_id', event.notification.tag || '0');
    appUrl.searchParams.set('notification_payload', payload);
    await clients.openWindow(appUrl.toString());
  })());
});

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(clients.claim()));
