# SUNUM.md — Müdüre sunum rehberi

> **Bu dosya iki bölümden oluşuyor:**
>
> - **BÖLÜM A — SUNUM:** sunumda söyleyeceğin başlıklar, sıra, cümleler, demo akışı.
> - **BÖLÜM B — SADECE SEN:** sunumda söylemene gerek olmayan ama **kesinlikle
>   bilmen gereken** notlar; müdürün sözleriyle teknik gerçek arasındaki farklar,
>   olası zor sorular, tuzaklar.
>
> **Bölüm B'yi sunumda açma.** Oradaki bilgiler seni soru karşısında ayakta
> tutmak için; slayt malzemesi değil.
>
> Tarih: 2026-10-18 · Durum: Faz 1 bitti, smoke test 10/10 geçiyor

---

# BÖLÜM A — SUNUM

## A0. Sunum stratejisi: anlatma, göster

Müdürün istediği şey somut: *"ben VSCode'da kodumu yazayım ve çalışsın."*
Bu, slayt değil **demo** isteyen bir cümle. Bu yüzden sunumun ağırlığı canlı
gösterimde olmalı.

**Önerilen süre dağılımı (toplam ~12 dakika):**

| Dk | Ne |
|---|---|
| 0–1 | Görev neydi → ne teslim edildi (tek tablo) |
| 1–4 | **Demo 1:** VSCode'da derle ve çalıştır, Hello World + sayaç |
| 4–7 | **Demo 2:** F5 ile debug — breakpoint, değişken, register |
| 7–9 | **Demo 3:** Timer interrupt'ın içine girip kesmeyi canlı yakala |
| 9–10 | Otomatik regresyon testi: 10/10 |
| 10–11 | Ortamın sınırları (dürüst slayt) |
| 11–12 | Gerçek kart gelince ne olacak + karar istediğim 3 nokta |

**Altın kural:** İlk üç dakikada ekranda çalışan bir şey olsun. Müdür
"çalışıyor" gördükten sonra geri kalan her şeyi daha rahat dinler.

---

## A1. Açılış: görev → teslim (1 dakika, tek tablo)

Açılış cümlesi:

> "Verdiğiniz görevin beş maddesi vardı. Hepsi çalışıyor, şimdi canlı
> göstereceğim. Üstüne iki şey ekledim: ortamın başka bilgisayarlara tek
> komutla kurulması ve her değişiklikten sonra kendini test etmesi."

Sonra bu tabloyu göster:

| Senden istenen | Teslim edilen | Durum |
|---|---|---|
| QEMU'da simülasyon ortamı | `qemu-system-riscv32`, RV32IMAC hedefi, tek komutla kurulum | ✅ |
| "VSCode'da kodumu yazayım ve çalışsın" | VSCode task'ları + IntelliSense; **Ctrl+Shift+B** derler, tek task çalıştırır | ✅ |
| "Hello World yazsa bile olur" | UART'a banner + her saniye durum satırı | ✅ |
| "Debug yapabileceğim bir sistem" | **F5** ile GDB: breakpoint, adımlama, değişken/register/CSR okuma-yazma, C ve assembly birlikte | ✅ |
| "Interrupt zamanlayıcısı kurabileceğim" | RISC-V CLINT zamanlayıcısı, 100 ms periyotla kesme, kesme işleyicisi | ✅ |
| *(ekstra)* Taşınabilirlik | `tools\setup.ps1` — boş bir makinede baştan sona kurar | ✅ |
| *(ekstra)* Regresyon testi | `tools\smoke-test.ps1` — 10 kontrol, otomatik, çıkış kodu döner | ✅ |

**Rakamlar (sorulursa):** 6 kaynak dosya, ~700 satır, üretilen firmware
**2 KB**, RAM kullanımı %0.27.

---

## A2. Demo 1 — "Kodumu yazayım ve çalışsın" (3 dakika)

**Hazırlık:** VSCode açık, `main.c` ekranda, terminal temiz.

**Adımlar:**

1. `main.c` içinde `print_banner()` fonksiyonundaki bir yazıyı değiştir —
   örneğin müdürün adını ekle. **Bunu canlı yap, hazır yapma.**
2. **Ctrl+Shift+B** → derleme task'ı koşar. Terminalde:
   ```
   [CC]  main.c
   [LD]  firmware.elf
   RAM:  22544 B / 8 MB  (0.27%)
   ```
3. Terminalden `mingw32-make run` (veya "run (QEMU)" task'ı) → çıktı:
   ```
   ===========================================
    Hello, World!
    RTG4 / Mi-V RV32 firmware - QEMU SiL
   ===========================================
    Platform   : QEMU riscv32 'virt'
    RAM base   : 0x80000000     CLINT base : 0x02000000
    UART base  : 0x10000000     mtime freq : 10000000 Hz
    Tick       : 100 ms
   -------------------------------------------
   Zamanlayici kesmesi aktif. Sayac ilerliyor...

   [tick 10] uptime = 1 s
   [tick 20] uptime = 2 s
   [tick 30] uptime = 3 s
   ```
4. **Birkaç saniye bekle, satırların canlı akmasına izin ver.** Bu, kesmenin
   gerçekten çalıştığının en görsel kanıtı.
5. Çıkış: **Ctrl+A, sonra X**.

**Söylenecek cümle:**

> "Döngü sayıp durmuyor. İşlemci `wfi` ile uyuyor, donanım zamanlayıcısı her
> 100 ms'de kesme üretiyor, kesme işleyicisi sayacı artırıyor. Ekrandaki her
> satır gerçek bir donanım kesmesinin sonucu."

---

## A3. Demo 2 — Debug (3 dakika)

Bu, müdürün özellikle istediği iki ekstradan biri. Önemli göster.

**Adımlar:**

1. `main.c`'de bir satıra tıkla, breakpoint koy (kırmızı nokta).
2. **F5.** Arka planda: derleme → QEMU durdurulmuş halde başlar → GDB bağlanır
   → `main`'de durur.
3. Göster:
   - **Variables** panelinde `g_tick_count` değeri
   - **F10 / F11** ile satır satır adımlama
   - **Watch** paneline `$mcause`, `$mtvec`, `$mepc` ekle — CSR'lar canlı okunuyor
   - Debug Console'da `-exec p/x $mtvec` → `0x8000007c`
4. Bir değişkenin değerini **debugger'dan değiştir** (`-exec set var g_tick_count = 4242`)
   ve devam ettir. "Sadece izlemiyorum, müdahale de edebiliyorum."

**Söylenecek cümle:**

> "VSCode'un normal debug arayüzü. Gömülü tarafta farklı olan tek şey, kodun
> bu bilgisayarda değil simüle edilen RISC-V işlemcisinde koşuyor olması.
> Breakpoint, adımlama, register görme — hepsi aynı."

**İkinci konfigürasyon (vaktin varsa):** `launch.json`'da "startup.S `_start`'ta
dur" seçeneği var. Seçersen işlemcinin **ilk komutunda**, assembly kaynağında
durur. "Reset'ten itibaren her komutu izleyebiliyoruz" demek için iyi.

---

## A4. Demo 3 — Interrupt'ın içine girmek (2 dakika)

Bu demo, "interrupt zamanlayıcısı kurabileceğim" maddesinin kanıtı.

**Adımlar:**

1. `main.c`'deki `trap_handler()` fonksiyonuna breakpoint koy.
2. F5 → devam et. Breakpoint **kendiliğinden** tetiklenir (100 ms sonra).
3. Göster:
   - `$mcause` = `0x80000007` → "makine zamanlayıcı kesmesi" kodu
   - `$mepc` → kesmenin tam olarak hangi komutu böldüğü
   - **Call Stack** paneli: `trap_handler` ← `trap_entry` → yani C kodu ile
     assembly kesme girişi birlikte izlenebiliyor
4. Devam ettir, breakpoint tekrar tetiklenir → periyodik olduğunu göster.

**Söylenecek cümle:**

> "Kesme periyodunu tek bir sabitle ayarlıyoruz; şu an 100 ms. Kesme
> içinde ne yapılacağı tek bir C fonksiyonunda — ekip buraya kendi işini
> yazacak. Mekanizmanın tamamı görünür durumda, kapalı bir kütüphane değil."

---

## A5. Otomatik regresyon testi (1 dakika)

```powershell
powershell -ExecutionPolicy Bypass -File tools\smoke-test.ps1
```

Çıktının son satırı:

```
  10 / 10 kontrol gecti
  TUM KONTROLLER GECTI
```

**Söylenecek cümle:**

> "Bu betik derliyor, QEMU'da koşturuyor, çıktıyı kontrol ediyor, sonra
> debugger'ı bağlayıp kesme vektörünün doğru kurulduğunu ve kesmenin
> tetiklendiğini doğruluyor. On kontrol. Çıkış kodu döndürdüğü için
> ileride otomatik derleme sistemine (CI) bağlanabilir. Yani ortam
> bozulduğunda bunu insan gözüyle değil, test ile anlıyoruz."

Bu madde müdürün istemediği bir ekstra ama **profesyonellik sinyali** olarak
en güçlü kalemlerden biri. Fazla üstünde durmadan geç, ama mutlaka göster.

---

## A6. Ortamın sınırları — dürüst slayt (1 dakika)

**Bu slaydı atlama.** Sonradan ortaya çıkan sınır, baştan söylenen sınırdan
çok daha pahalıya gelir.

| Bu ortam **doğrular** | Bu ortam **doğrulamaz** |
|---|---|
| Uygulama mantığı, durum makineleri | Gerçek çevre birimlerin davranışı |
| Kesme ve zamanlayıcı mantığı | Saat/ısı/radyasyon etkileri |
| Zaman hesapları, protokol kodlama | Komut başına gerçek cycle süresi |
| Regresyon: "eskiden çalışan bozuldu mu" | FPGA içi zamanlama (timing closure) |

**Söylenecek cümle:**

> "Komut kümesi ve kesme mimarisi birebir aynı — o tarafta taviz yok.
> Taviz verdiğimiz yer çevre birimler: ekranda gördüğünüz seri port QEMU'nun
> standart portu, gerçek karttaki port değil. Bu yüzden ortam yazılım
> mantığını doğrular, donanım davranışını doğrulamaz. Yazılım hatalarının
> büyük bölümü ilk gruptadır, o yüzden bugünden itibaren kullanılabilir."

---

## A7. Gerçek kart gelince ne olacak (1 dakika)

Bu, projenin asıl mühendislik değeri. Tek slayt:

> **Uygulama kodunda hiçbir yerde çıplak donanım adresi yok.** Tüm adresler
> tek bir dosyada (`platform.h`) isimli sabitler olarak duruyor. Hedef
> değiştirmek tek bir derleme parametresi:

```powershell
mingw32-make                              # simülasyon
mingw32-make PLATFORM=PLATFORM_RTG4_MIV   # gerçek kart hedefi
```

> "Kesme mantığının tek satırı değişmiyor. Gerçek kart hedefi için de
> **derlendiğini doğruladım** — ama kart elimizde olmadığı için üzerinde
> çalıştığını iddia etmiyorum. Kart geldiğinde yapılacak iş, o dosyadaki
> adresleri donanım tasarımının gerçek değerleriyle doğrulamak."

---

## A8. Kapanış: karar istediğim 3 nokta (1 dakika)

Sunumu "bitti" diye değil, **müdürden girdi isteyerek** kapat. Bu, işi
sahiplendiğini gösterir.

1. **Ekip bu ortamı ne zaman kullanmaya başlasın?** Bugünden hazır; isterseniz
   bir kişiyle deneme turu yapıp kurulum adımlarını sadeleştirebilirim.
2. **Kodu sürüm kontrolüne alalım mı?** Şu an versiyonlama yok. Depoya
   hazırlık yapıldı; onay verirseniz ilk commit'i atıp ekibe açarım.
3. **Hangi çevre birimler öncelikli?** Seri port hazır. Gerçek projede
   GPIO/SPI gibi birimler gerekecekse hangisinin önce geldiğini bilmem,
   doğru sırayla eklemem lazım.

**Kapanış cümlesi:**

> "Özetle: istediğiniz beş maddenin hepsi çalışıyor, ortam başka
> bilgisayarlara taşınabilir durumda ve gerçek karta geçiş için kod
> hazırlandı. Bundan sonrası ekibin hangi yöne gitmek istediğine bağlı."

---
---

# BÖLÜM B — SADECE SEN (sunumda söylemene gerek yok)

## B1. Müdürün cümlesindeki teknik boşluk: "RTG-4 işlemcisi"

**Gerçek:** RTG4 bir **işlemci değil, FPGA**. Microchip'in radyasyona dayanıklı
uzay FPGA'i. İçinde hazır bir CPU **yok**. İşlemci, FPGA dokusuna
*sentezlenen* bir RISC-V çekirdeği — Microchip'in bu amaçla verdiği hazır
çekirdek ailesinin adı **Mi-V** (örn. `MIV_RV32`), ve bu sentez işi
Microchip'in **Libero SoC** aracıyla yapılır.

Yani müdürünün "RTG-4 işlemcisi" dediği şey, teknik olarak "RTG4 FPGA'ine
yerleştirilmiş bir RISC-V soft-core". Mi-V ve Libero'dan bahsetmemiş olması
normal — **bunlar RTG4 üzerinde RISC-V çalıştırmanın kaçınılmaz sonucu**,
senin uydurduğun bir yön değil.

**Bunu sunumda nasıl yöneteceksin:**

- ❌ **Yapma:** "Aslında RTG4 bir işlemci değil, siz yanlış biliyorsunuz."
- ✅ **Yap:** Konuyu düzeltme olarak değil, **bilgi olarak** sun. Sadece
  gerekirse, geçerken:

  > "RTG4'te işlemci FPGA dokusuna yerleştirilen bir RISC-V çekirdeği olduğu
  > için, ortamı doğrudan o çekirdeğin komut kümesine göre hedefledim —
  > RV32IMAC. Komut kümesi ve kesme mimarisi tarafında bire bir aynı."

Bu cümle üç işi birden yapıyor: doğru bilgiyi kayda geçiriyor, müdürü
düzeltmiş gibi olmuyor, ve senin konuyu bildiğini gösteriyor.

**Neden bu önemli:** Eğer sunumda "RTG4 işlemcisini simüle ettim" dersen ve
odada FPGA tarafını bilen biri varsa, o cümle üzerinden gidilir. "RTG4 üzerinde
koşacak RISC-V çekirdeğini hedefledim" dersen bu risk yok.

---

## B2. En kritik nokta: "QEMU'da zaten RISC-V ortamı var" — yarı doğru

Müdürün bu cümlesi sunumun **tek gerçek risk noktası**, çünkü eksik bir
varsayım içeriyor ve senin işinin değerini de gizliyor.

| Müdürün varsayımı | Gerçek |
|---|---|
| QEMU'da RISC-V desteği var | ✅ **Doğru.** `qemu-system-riscv32` var, RV32IMAC çalışıyor |
| → o yüzden "RTG4'ü QEMU'da aç" basit bir iş | ❌ **Burada boşluk var** |

**Gerçek:** QEMU'da **RTG4 veya Mi-V makine modeli yok.** QEMU'nun sunduğu şey
`virt` adlı **genel amaçlı** bir RISC-V platformu. Yani kutudan çıkan şey
"RTG4 simülatörü" değil, "RISC-V işlemci simülatörü". Aradaki farkı kapatan
şey senin yaptığın iş:

- Doğru komut kümesiyle derleyen bir toolchain zinciri
- `linker.ld` ile doğru bellek yerleşimi (RAM `0x80000000`)
- `startup.S` ile reset kodu — stack, `.bss`, global pointer, kesme vektörü
- CLINT zamanlayıcısı ve trap mekanizmasının elle kurulması
- Adreslerin tek dosyada soyutlanması (`platform.h`) → gerçek karta geçiş yolu

**Bunu sunumda nasıl söyleyeceksin:**

- ❌ **Yapma:** "QEMU'da RTG4 yok, o yüzden istediğiniz şey mümkün değildi."
  (Olumsuz açılış, görev başarısız gibi duyulur.)
- ✅ **Yap:** Olumlu çerçevede, A6/A7 slaytlarında doğal olarak geçir:

  > "QEMU'nun RISC-V desteğini kullandım, doğru tahmin. QEMU'nun verdiği şey
  > genel bir RISC-V platformu; RTG4'e özgü hazır bir model yok. Bu yüzden
  > işlemci tarafını birebir eşledim, çevre birim adreslerini de tek bir
  > dosyada soyutladım — kart geldiğinde o dosyadaki değerleri gerçek
  > tasarımdan doğrulamak yeterli olacak."

**Bunu mutlaka söyle.** Sessiz kalırsan müdür "demek ki RTG4 simülasyonu
bitti, ekip çevre birim kodu yazsın" diye düşünür ve bu beklenti sonra patlar.

---

## B3. Mi-V ve Libero'yu sen gündeme getirme — ama hazır ol

Müdür bu iki kelimeyi söylemedi. **Sunumun merkezine koymaman doğru olur:**
istemediği bir şeye kaymış gibi görünür ve ana mesajı ("çalışıyor")
gölgeler.

**Strateji:** İkisini de **"gerçek kart gelince" bağlamına** sakla (A7 slaydı).
O bağlamda tamamen doğal duruyorlar, çünkü soru "kart gelince ne yapacağız"
olduğunda cevap zaten bunlar.

**Sorulursa tek cümlelik cevaplar:**

- *"Mi-V nedir?"* → "Microchip'in FPGA'lere yerleştirmek için verdiği hazır
  RISC-V çekirdeği. RTG4'te işlemci olarak muhtemelen bu kullanılacak."
- *"Libero ne?"* → "Microchip'in FPGA tasarım aracı. Çevre birimlerin hangi
  adreste olduğu o tasarımda belirlenir; bizim doğrulamamız gereken sayılar
  oradan geliyor."
- *"Bunları kim yapacak?"* → **Dürüst ol:** "Donanım/FPGA tarafı. Benim
  ihtiyacım sadece beş sayı: bellek tabanı, zamanlayıcı adresi, seri port
  adresi ve iki saat frekansı."

**Bu son cevap senin için çok değerli:** Belirsiz bir "FPGA ekibiyle
görüşülmeli" yerine **somut, kısa bir istek** sunuyorsun. Yöneticiler bunu
sever ve bu, projenin bir sonraki adımını senin eline verir.

---

## B4. İstenenden fazla yaptığımız şeyler — gerekçeleriyle

Müdür "çok geniş çaplı olmasına gerek yok" dedi. Eğer "neden bu kadar
uzattın" sorusu gelirse, savunma hazır olsun. Yapılan ekstralar ve **her
birinin gerekçesi**:

| Ekstra | Neden yapıldı | Sorulursa cevap |
|---|---|---|
| `platform.h` ile iki hedef | Tek `-D` ile gerçek karta geçiş | "Maliyeti neredeyse sıfırdı; sonradan eklemek tüm kodu elden geçirmek demekti." |
| `tools\setup.ps1` | Bu makine **tamamen boştu**, her şey sıfırdan kuruldu | "Kurulumu zaten bir kez yaptım; betiğe dökmek ekstra iş değil, ekibin aynı şeyi tekrar yaşamaması için." |
| `smoke-test.ps1` | Ortamın bozulduğunu insan gözüyle fark etmek zor | "Bir kez yazıldı, her değişiklikte koşuyor. Zaten bir hatayı bu test yakaladı." |
| 4 dosyalık dokümantasyon | Sen devralma riskini azaltmak | "Ortamı ben kurdum; ben olmasam da ekibin devam edebilmesi lazım." |
| `linker.ld` içinde `ASSERT` | Taşma derleme anında hata verir | "Çalışma anında anlaşılmaz çökme yerine derleme hatası." |

**Asıl savunma cümlesi (gerekirse):**

> "Teslim ettiğim firmware 2 KB ve 6 dosya — kapsamı genişletmedim. Fazladan
> yaptığım şey kodun kendisi değil, **çevresi**: kurulumun tekrarlanabilir
> olması ve ortamın kendini test etmesi. İkisi de ekibin bu ortamı gerçekten
> kullanabilmesi için gerekiyordu."

Ayrıca unutma: müdürün "çok iyi olur" dediği iki şey (debug + interrupt)
**opsiyoneldi ve ikisi de yapıldı**. Bu, kapsamı aşmak değil, istenen
opsiyonu teslim etmek.

---

## B5. Asla söylememen gerekenler

Bunlar seni sonradan zora sokacak cümleler:

1. ❌ **"RTG4'ü simüle ediyoruz."**
   ✅ "RTG4 üzerinde koşacak RISC-V çekirdeğini hedefliyoruz."
   *Birincisi çevre birimleri de kapsıyormuş gibi duyulur.*

2. ❌ **"Ekip artık tüm firmware'i burada geliştirip test edebilir."**
   ✅ "Uygulama mantığını burada geliştirip test edebilir; çevre birim
   sürücüleri kart üzerinde doğrulanmalı."

3. ❌ **"Kart gelince kod doğrudan çalışır."**
   ✅ "Kod derlenir ve mantık aynı kalır; adreslerin doğrulanması gerekir."
   *"Doğrudan çalışır" dersen, çalışmadığı gün bu cümle hatırlanır.*

4. ❌ **"Zamanlama birebir doğru."**
   ✅ "Zaman **mantığı** doğru — kaç tick geçti, periyot doğru hesaplandı mı.
   Cycle seviyesinde gerçek donanım zamanlaması değil."
   *Testimiz bile 100 ms tick'te 3–5 saniyelik koşumda tolerans bırakıyor;
   QEMU host hızında koşuyor.*

5. ❌ **"Simics'e gerek yoktu / Simics'ten iyi."**
   ✅ "Simics'in getirisi cihaz seviyesinde modellemeydi; bu ortam o
   katmanı sağlamıyor. Lisans alınamadığı için mevcut en iyi alternatif bu."
   *Simics konusu lisans kararıydı ve senin kararın değil. Küçümseme —
   bir gün tekrar gündeme gelebilir.*

6. ❌ **Çalışmadığı bir şeyi çalışıyor gibi anlatmak.** Gerçek kartta
   **hiç denenmedi**, sadece **derlendi**. Bu ikisi arasındaki farkı her
   cümlede koru.

---

## B6. Muhtemel sorular ve kısa cevaplar

| Soru | Cevap |
|---|---|
| "Gerçek kartta çalıştı mı?" | "Hayır, kart yok. Gerçek kart hedefi için derlendiğini doğruladım, üzerinde koşmadı." |
| "Ekip yarın kullanmaya başlayabilir mi?" | "Evet. Kurulum betiği var, bir kişiyle deneme turu yapmayı öneririm." |
| "Bizim gerçek projemizin kodu burada koşar mı?" | "Mantık tarafı evet. Çevre birim sürücüleri — seri port dışında — burada karşılığı olmadığı için ya taklit edilmeli ya kartta denenmeli." |
| "Ne kadar sürdü?" | Dürüst söyle. Makine tamamen boştu; toolchain + QEMU kurulumu, derleme sistemi, reset kodu, kesme altyapısı, debug zinciri, test ve dokümantasyon. |
| "Başka bilgisayara kurmak ne kadar sürer?" | "Tek komut; indirme süresi ~500 MB, onun dışında elle iş yok. Node.js önkoşul." |
| "Linux'ta çalışır mı?" | "Kaynak kod ve derleme sistemi aynen çalışır. Yardımcı betikler PowerShell; onların Linux karşılığı yazılmalı — yarım günlük iş." |
| "Interrupt periyodunu nasıl değiştiririz?" | "`main.c`'de tek bir sabit — `TICK_HZ`. Şu an 10, yani 100 ms." |
| "Birden fazla kesme kaynağı ekleyebilir miyiz?" | "Evet. Zamanlayıcı dışı kesmeler için standart RISC-V kesme denetleyicisi (PLIC) var; aynı desenle ekleniyor, yarım günlük iş." |
| "Neden Hello World'den fazlasını yapmadın?" | "İstediğiniz kapsam buydu. Üstüne koyduğum iki şey debug ve zamanlayıcıydı — ikisi de sizin listenizdeydi. Ortamın kendisi genişlemeye hazır." |
| "printf neden yok?" | "Standart kütüphane bağlamadım; bare-metal'de `printf` hem büyük hem işletim sistemi çağrısı bekliyor. Kendi seri port fonksiyonlarımız var. İstenirse hafif bir `printf` eklenir." |
| "Maliyeti ne?" | "Sıfır. QEMU ve derleyici açık kaynak, lisans yok." |

---

## B7. Seni köşeye sıkıştırabilecek üç soru

**1) "Yani bu sadece bir RISC-V simülatörü, RTG4'le ilgisi yok mu?"**

Sakin cevap:

> "İşlemci tarafıyla birebir ilgisi var — komut kümesi ve kesme mimarisi aynı.
> İlgisi olmayan taraf çevre birimler. Kodu da tam bu yüzden adresleri tek
> dosyada tutacak şekilde yazdım: RTG4'e geçiş bir yeniden yazma değil, bir
> yapılandırma değişikliği olacak."

**2) "Çevre birimler olmadan bu ortam gerçek projede ne işe yarar?"**

> "Yazılım hatalarının büyük bölümü çevre birimde değil mantıkta olur:
> durum makineleri, zaman hesapları, kesme içindeki veri paylaşımı, protokol
> kodlama. Bunların hepsi burada, kart beklemeden, dakikalar içinde test
> edilebiliyor. Kart geldiğinde o hatalar çoktan temizlenmiş olur."

**3) "Bunu neden Simics ile yapmadık?"**

> "Simics'in asıl getirisi cihaz seviyesinde modellemeydi, yani tam bu
> eksik katman. Lisans alınamadığı için QEMU'ya geçtik. İleride cihaz
> seviyesinde doğruluk kritik olursa iki yol var: lisans tekrar gündeme
> gelir, ya da QEMU'ya kendi cihaz modellerimizi yazarız — ikincisi haftalar
> mertebesinde bir iş."

---

## B8. Demo öncesi kontrol listesi

**Sunumdan 1 saat önce mutlaka:**

- [ ] `powershell -ExecutionPolicy Bypass -File tools\smoke-test.ps1` → **10/10 görmeden sunuma girme**
- [ ] F5 ile debug'ı bir kez dene (`main`'de durmalı)
- [ ] **VSCode'u yeniden başlat** ve tekrar dene — eski terminaller PATH'i görmüyor olabilir
- [ ] Arka planda kalmış QEMU var mı: `tools\qemu-stop.ps1`
- [ ] Terminal yazı boyutunu büyüt (Ctrl + `+`), projektörde okunsun
- [ ] `main.c` ve bir terminal açık, gereksiz sekmeler kapalı

**Canlı demoda patlayabilecek şeyler ve anında çözümleri:**

| Belirti | Çözüm | Demo sırasında ne dersin |
|---|---|---|
| `riscv-none-elf-gcc: command not found` | VSCode'u yeniden başlat | "Araç yolları yeni eklendi, terminal tazelenmesi gerekiyor." |
| F5 → "Unable to start debugging" | `tools\setup.ps1 -SkipInstall` | Demoyu terminalden `mingw32-make debug` + `gdb` ile kurtar |
| QEMU'dan çıkamıyorsun | **Ctrl+A, bırak, sonra X** | — |
| QEMU penceresi açılıp kapanıyor | Arka plandaki QEMU'ları `qemu-stop.ps1` ile temizle, tekrar F5 | — |
| Makefile `missing separator` | Dosyaya boşlukla girinti kaçmış | Demo sırasında Makefile'ı **düzenleme** |

**Güvenlik ağı:** Demo sırasında **canlı kod değişikliği sadece bir yerde yap**
— `print_banner()` içindeki bir yazı. Orası en güvenli nokta: derleme
kırılamaz, mantık bozulamaz. Kesme kodunu veya `platform.h`'yi canlı
kurcalamayı deneme.

---

## B9. Terminoloji kopya kâğıdı

Müdür bir kelimeyi sorarsa tek cümlelik cevap:

- **Soft-core:** FPGA dokusuna yazılımla yerleştirilen işlemci. Çip içinde
  hazır gelmez; tasarımla oluşturulur.
- **ISA (RV32IMAC):** İşlemcinin anladığı komut kümesi. `32` bit, `I` temel
  tamsayı, `M` çarpma/bölme, `A` atomik, `C` sıkıştırılmış komutlar.
- **CSR:** İşlemcinin kontrol register'ları. Kesme ayarları burada tutulur.
- **CLINT:** RISC-V'in standart zamanlayıcı ve yazılım kesmesi birimi.
  Periyodik kesmeyi bu üretiyor.
- **Trap / trap vector:** Kesme veya hata olduğunda işlemcinin atladığı adres.
  Biz `mtvec` register'ına kendi fonksiyonumuzun adresini yazıyoruz.
- **Linker script:** "Hangi kod hangi adrese gidecek" sorusunu cevaplayan
  dosya. Gömülü sistemde olmadan çalışan imaj üretilemez.
- **Bare-metal:** İşletim sistemi olmadan, doğrudan donanım üstünde koşan kod.
- **SiL (Software-in-the-Loop):** Yazılımı gerçek donanım olmadan, simüle
  edilmiş bir ortamda koşturarak doğrulama.
- **eNVM:** FPGA içindeki kalıcı bellek; gerçek kartta kod buradan açılacak.

---

## B10. Sunumdan çıkarken alman gereken şeyler

Toplantıdan "güzel, teşekkürler" ile çıkma. Şu üçünden en az ikisini netleştir:

1. **Sürüm kontrolü onayı.** Şu an kod versiyonlanmıyor ve bu gerçek bir risk —
   tek kopya, tek makine. Onay alırsan ilk işin bu olsun.
2. **O beş sayı kimden gelecek?** (bellek tabanı, zamanlayıcı adresi, seri port
   adresi, iki saat frekansı). İsim al, "FPGA ekibi" değil **kişi** al.
3. **Sıradaki iş ne?** Üç makul seçenek: (a) ekibe kurulum ve devir,
   (b) ek çevre birim desteği, (c) birim test altyapısı. Müdür seçsin —
   böylece sonraki hafta ne yaptığın tartışma konusu olmaz.

**Son bir not:** Bu projede en çok savunulabilir şey kodun kendisi değil,
**kodun yapısı**. "Hello World yazdım" ile "hedefi tek parametreyle
değiştirebilen, kendini test eden, başka makinede tek komutla kurulan bir
firmware iskeleti kurdum" arasındaki fark, senin bu sunumda anlatman gereken
fark. Demo bunu zaten gösteriyor; sen sadece doğru kelimelerle adını koy.
