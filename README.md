# İngilizce Shorts

Shorts gibi kendiliğinden kayan kartlarla İngilizce. **20.000 kelime + 4.000 cümle**,
en basit kelimeden başlayarak.

* Her kart telaffuz bittikten sonra **kendi kendine** kayar.
* **Ekrana dokununca durur.** Tekrar dokununca ya da kaydırınca akış devam eder.
* Sıralama: **5 kelime → 1 cümle → 5 kelime → 1 cümle …** (toplam 24.000 kart)
* Kelime kartında: kelime, Türkçe okunuşu, IPA, tür, Türkçe anlam +
  **örnek cümle** (İngilizcesi, Türkçe okunuşu, Türkçe anlamı).
* Cümle kartında: cümle, Türkçe okunuşu, Türkçe anlamı.
* Ayarlar: mod (otomatik/manuel), hız (4 kademe), içerik (5+1 / sadece kelime /
  sadece cümle), seslendirme (varsayılan **hızlı**: kelime kartında yalnız
  kelime, cümle kartında yalnız cümle okunur; istersen kelime + örnek cümle),
  Türkçe anlamı gizleme (kendini sınamak için),
  okunuşu gizleme, konum çubuğu.
* Kaldığın yer kaydedilir; çevrimdışı çalışır (PWA).

## Yerelde çalıştırma

```powershell
powershell -ExecutionPolicy Bypass -File serve.ps1        # http://localhost:8161
```

## Veri

| dosya | içerik |
|---|---|
| `veri/v00.js` … `v09.js` | parça başına 2.000 kelime + 400 cümle |
| `veri/meta.js` | kart sayıları |

Kelime satırı: `kelime|tür|Türkçe anlam|IPA|okunuş|örnek cümle|çevirisi|cümle okunuşu`
Cümle satırı: `English|Türkçe|okunuş`

Parçalar gerektikçe yüklenir (açılışta yalnızca ilk parça inar).

### Üretim

```bash
perl yapim/build.pl kelimeler.js cmudict.dict pairs.txt ../veri
```

* Kelime bankası + sıklık sırası: `seri-ingilizce/kelimeler.js`
  (altyazı sıklığı + CMU Pronouncing Dictionary). **Liste sırası = zorluk.**
* Okunuşlar CMUdict ARPAbet'ten üretilir; kelime kartında birincil vurgulu ünlü
  BÜYÜK harfle (`rimEmbır`), cümle içinde vurgu işareti yok.
* Cümleler [Tatoeba](https://tatoeba.org) eng–tur çiftlerinden (CC BY 2.0 FR).
  Puan = |uzunluk − 6| + (en nadir kelimenin sırası)/3000 + özel isim cezası +
  okunuşu bulunamayan kelime cezası; en düşük puanlı cümle seçilir.
* 20.000 kelimenin 17.284'ünde örnek cümle var; kalanların çoğu altyazı
  bankasından gelen özel isim/ünlem (`eddie`, `mmm`) — Tatoeba'da geçmiyor.
* Cümle kartı, o bloktaki 5 kelimeden birini içeren en kolay cümleden seçilir;
  kelime kartlarında örnek olarak geçen cümleler cümle kartında tekrar etmez.

Sürüm yayınlarken `sw.js` içindeki `CACHE` artmalı.
