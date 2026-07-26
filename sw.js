/* Ingilizce Shorts - cevrimdisi calisma
   Kabuk (index.html, sw disi dosyalar): once ag, olmazsa onbellek -> guncelleme
   hemen gelir.  Veri parcalari (veri/*.js): once onbellek -> hem hizli hem
   cevrimdisi.  Surum yayinlarken CACHE artmali. */
const CACHE = 'ing-shorts-v4';
const KABUK = ['./', './index.html', './manifest.json', './icon.svg', './veri/meta.js', './veri/v00.js'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(KABUK)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

function sakla(istek, cevap) {
  if (cevap && cevap.ok && new URL(istek.url).origin === self.location.origin) {
    const kopya = cevap.clone();
    caches.open(CACHE).then(c => c.put(istek, kopya));
  }
  return cevap;
}

self.addEventListener('fetch', e => {
  const istek = e.request;
  if (istek.method !== 'GET') return;
  const yol = new URL(istek.url).pathname;
  const veri = /\/veri\/[^/]+\.js$/.test(yol);

  if (veri) {                                   // veri: once onbellek
    e.respondWith(
      caches.match(istek, {ignoreSearch: true}).then(
        b => b || fetch(istek).then(c => sakla(istek, c))
      )
    );
    return;
  }
  e.respondWith(                                // kabuk: once ag
    fetch(istek).then(c => sakla(istek, c))
      .catch(() => caches.match(istek, {ignoreSearch: true}))
  );
});
