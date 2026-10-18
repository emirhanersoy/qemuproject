# ozet.md — Hızlı özet + uygulamalı debug senaryoları

> Video çekerken yanında duracak dosya. Üç bölüm:
> **A)** anlatılacak özet · **B)** bilmediğim fonksiyonlar ve kesme · **C)** 6 uygulamalı senaryo

---

# BÖLÜM A — Sunumda/videoda okuyacağın özet

> RTG4 kartı henüz gelmediği için, geliştirmeyi bugün başlatabilmek adına QEMU
> üzerinde bir simülasyon ortamı kurdum. RTG4 içinde RISC-V komut kümesiyle
> çalışan bir işlemci olduğu için, QEMU'nun RISC-V `virt` makinesini hedef
> aldım — komut kümesi ve kesme mimarisi gerçek çiple **birebir aynı**.
>
> Derleyici olarak `riscv-none-elf-gcc` cross-compiler'ını kullandım: bu
> bilgisayarda çalışıyor ama RISC-V için kod üretiyor.
>
> VSCode'a entegre ettim — `.vscode` altındaki konfigürasyonlarla
> **Ctrl+Shift+B** derliyor, **F5** debug başlatıyor. Derleme adımlarını
> `Makefile` yönetiyor.
>
> İşletim sistemi olmadığı için (bare-metal) normalde OS'un yaptığı işleri biz
> yapıyoruz: yığın kurulumu, bellek yerleşimi, kesme vektörü. Bunlar
> `startup.S` ve `linker.ld`'de.
>
> Tüm donanım adresleri tek bir dosyada — `platform.h` — isimli olarak duruyor.
> İki set var: biri QEMU, biri gerçek RTG4. Hedef değiştirmek tek parametre,
> uygulama kodu hiç değişmiyor.
>
> Uygulama her saniye UART'tan bir satır basıyor — ama **döngüyle değil,
> zamanlayıcı kesmesiyle.** İşlemci `wfi` ile uyuyor, donanım onu her 100
> ms'de uyandırıyor.
>
> Ortamda tam debug desteği var: breakpoint, adım adım çalıştırma, register ve
> CSR inceleme, değişkenleri çalışma anında değiştirme. Ayrıca her
> değişiklikten sonra kendini test eden bir betik var, şu an **10/10** geçiyor.

---

## A.1 Karıştırılmaması gereken 3 şey

### ① Derleyicinin adı `riscv-none-elf-gcc`

`mingw-none-gcc` **değil**. İsmi parça parça anlamlı:

| Parça | Anlamı |
|---|---|
| **`riscv`** | Üreteceği kod RISC-V için |
| **`none`** | **İşletim sistemi yok** (bare-metal) |
| **`elf`** | Çıktı dosya formatı |

`mingw32-make` **derleyici değil** — derleme komutlarını sırayla çalıştıran
yardımcı (şef / menajer). Müdürün sorabileceği bir detay, ikisini ayır.

### ② `mingw32-make` ile `mingw32-make run` farkı

```
mingw32-make        → derler, firmware.elf üretir    (startup.S burada DERLENİR)
mingw32-make run    → QEMU'yu başlatır               (startup.S burada ÇALIŞIR)
```

`run` komutu QEMU'yu açar → QEMU `firmware.elf`'i belleğe yükler → işlemci
`0x80000000` adresinden başlar → orada `startup.S` var.

### ③ "QEMU donanım register'ı gibi davranıyor" — net hali

> "Kod bir **bellek adresine** yazıyor. Gerçek kartta o adreste UART donanımı
> var. QEMU'da ise o adresi QEMU dinliyor ve terminale harf basıyor. **Kod
> ikisini ayırt edemiyor** — simülasyonun çalışma prensibi tam olarak bu."

---

# BÖLÜM B — Fonksiyonlar ve kesme

## B.1 Önce benzetme: CLINT = duvar saati + alarm kolu

| | Ne | Özelliği |
|---|---|---|
| **`mtime`** | Saatin kendisi | **Durmadan ileri sayar.** Durdurulamaz, sıfırlanamaz |
| **`mtimecmp`** | Alarm kolu | "Saat şu değere gelince beni uyandır" |

İkisi de bellekteki birer adres. QEMU'da `mtime` saniyede **10.000.000** artıyor.

## B.2 Altı fonksiyon, altı cümle

| Fonksiyon | Ne yapıyor | Benzetme |
|---|---|---|
| `mtime_read()` | Saatin **şu anki** değerini okur | "Saat kaç?" |
| `mtimecmp_write(x)` | Alarm kolunu `x` değerine kurar | "Beni 7'de kaldır" |
| `timer_schedule_next()` | `mtimecmp = mtime + 1.000.000` → **100 ms sonrası** | "Beni 100 ms sonra kaldır" |
| `timer_start()` | İlk alarmı kurar **+ kesmeleri açar** | "Alarmı kur ve sesi aç" |
| `trap_handler()` | **Alarm çaldığında çalışan fonksiyon** | Uyanınca yaptığın iş |
| `print_banner()` | Ekrana başlık/adresleri basar | Sadece süs, mantığı yok |

## B.3 `mtime_read` neden 9 satır

İş basit: "bir sayı oku". Ama:

**Saat 64 bitlik, işlemci 32 bitlik.** Sayıyı tek seferde okuyamıyoruz —
**iki parça** halinde okuyoruz: üst yarı + alt yarı.

Problem: iki okuma arasında saat ilerliyor. Dijital saatte önce saati sonra
dakikayı okumak gibi — `07:59` okurken tam o anda `08:00` olursa `07:00`
okumuş olabilirsin. **Bir saat yanlış.**

Çözüm (`main.c` satır 34-37): **üst → alt → üst tekrar oku.**
Üst yarı değişmemişse okuma güvenli, kabul et. Değişmişse baştan yap.

`mtimecmp_write` de aynı sebepten 3 adımlı (satır 51-53): yarısı yazılmış bir
alarm değeri **yanlışlıkla alarmı hemen çaldırabilir.** O yüzden önce alarmı
imkânsız bir değere (`0xFFFFFFFF`) çekip, sonra gerçek değeri yazıyor.

> **Söylenecek hali:** "64-bitlik sayacı 32-bitlik işlemcide güvenli okumak
> için RISC-V spesifikasyonunun önerdiği yöntemi uyguladım."

---

## B.4 Kesme nedir — en basit hali

### Döngü ile beklemek vs kesme

Her saniye ekrana yazı yazacaksın. İki yol:

**Yol 1 — döngü (polling):** sürekli saate bakmak.

```c
while (1) {
    if (mtime_read() >= hedef) {   // saate bak
        yaz();
        hedef += 1 saniye;
    }
}
```

İşlemci saniyede milyonlarca kez saate bakar. **%100 CPU, boşa.** Gerçek
kartta pil biter.

**Yol 2 — kesme (bizim yaptığımız):** alarm kur, uyu.

```c
timer_start();          // alarmı kur
while (1) {
    wfi;                // UYU
    // alarm çalınca burada uyanıyoruz
}
```

İşlemci **hiçbir şey yapmıyor**, uyuyor. Alarm çaldığında **donanım** onu
uyandırıyor.

### "Kesme" kelimesi neden kesme

Çünkü programı **ortasından keser.** Sen fonksiyon çağırmıyorsun — **donanım**
araya giriyor:

```
main() satır 146'da uyuyor
        |
        |  <-- ALARM! (donanım araya girdi, main'in haberi yok)
        v
   trap_entry  (startup.S)     <-- register'ları yığına kaydet
        v
   trap_handler()              <-- g_tick_count++        (satır 86)
                               <-- timer_schedule_next() (satır 87)
        v
   trap_entry / mret           <-- register'ları geri yükle
        |
        v
main() satır 148'de devam ediyor   <-- hiçbir şey olmamış gibi
```

**Kritik nokta:** `main` hiçbir yerde `trap_handler`'ı **çağırmıyor.**
`main.c`'de arama yap, bulamazsın. Buna rağmen saniyede 10 kez çalışıyor.
İşte kesme bu.

### Üç şalter

Alarmın çalması için **üçü birden** açık olmalı:

| # | Koşul | Kodda |
|---|---|---|
| 1 | Alarm vakti geldi (`mtime >= mtimecmp`) | `timer_schedule_next()` kurar |
| 2 | Zamanlayıcı kesmesi açık | `csr_set(mie, MIE_MTIE)` — satır **69** |
| 3 | **Genel** kesmeler açık | `csr_set(mstatus, MSTATUS_MIE)` — satır **70** |

Üçünden biri kapalıysa hiçbir şey olmaz. `timer_start()` tam olarak bu üçünü
yapıyor.

### En kritik tek satır: 87

RISC-V alarmı **tek seferlik.** Çaldıktan sonra kendini yeniden kurmaz —
telefonundaki "her gün tekrarla" seçeneği kapalı gibi.

```c
timer_schedule_next();   // main.c:87 — alarmı yeniden kur
```

**Bu satır silinirse:** ilk alarm çalar, `g_tick_count` 1 olur, sonra sistem
**sonsuza kadar susar.** Projenin en kritik tek satırı.
Demoda gösterilecek → **Senaryo 5**.

---

# BÖLÜM C — Uygulamalı debug senaryoları

## C.0 Önce iki şey

**`-exec` ne demek:** VSCode'un **DEBUG CONSOLE** sekmesine yazdığın satırın
başına `-exec` koyarsan, VSCode onu GDB'ye komut olarak iletir. `-exec`
olmadan yazarsan VSCode onu değişken ifadesi sanar.

**Başlangıç her senaryoda aynı:** **F5** → *"QEMU: Debug (main icinde dur)"*

**Senaryo 5 öncesi yedek al:**
```powershell
copy main.c main.c.yedek
```

---

## Senaryo 1 — "Kesme gerçekten oluyor mu?" ⭐ en etkileyici

**Breakpoint:** `main.c` satır **86** (`g_tick_count++;`)

F5 → **F5 tekrar** (devam et). Breakpoint'e düşecek.

DEBUG CONSOLE:
```
-exec p/x $mcause
```
Göreceğin: **`0x80000007`**

Nasıl okunur:
- **`8`** ile başlıyor → en üst bit 1 → "bu bir **kesme**, hata değil"
- son hane **`7`** → "**zamanlayıcı** kesmesi"

```
-exec p g_tick_count
```
`0`, `1`, `2`... her F5'te bir artıyor.

```
-exec p/x $mepc
```
**Kesilen komutun adresi** — yani `main`'in `wfi` satırı. Program oraya dönecek.

### Asıl numara: CALL STACK paneli

```
trap_handler()      <-- şu an buradayız
trap_entry()        <-- buraya assembly'den geldik
```

`main` **yok.** Çünkü `main` bizi çağırmadı — **donanım** çağırdı.
Kesmenin kanıtı tam olarak bu paneldir.

> **Söyleyeceğin cümle:** "Call Stack'te `main` görünmüyor. Bu fonksiyonu
> kimse çağırmadı, donanım araya girdi. Kesme budur."

---

## Senaryo 2 — "Alarm kaça kuruldu?"

**Breakpoint:** `main.c` satır **63** (`timer_schedule_next` içi)

```
-exec p/d mtime_read()
```
Saatin şu anki değeri, örn. `12480000`.

```
-exec p MTIME_STEP
```
**`1000000`** → 10 MHz / 10 Hz = bir tick'te saat bu kadar ilerliyor = **100 ms**.

Şimdi donanımın gerçek belleğine bakalım:

```
-exec x/2xw 0x02004000
```
`mtimecmp` (alarm kolu). İki 32-bitlik kelime: alt yarı + üst yarı.

```
-exec x/2xw 0x0200bff8
```
`mtime` (saatin kendisi). **İki kere üst üste çalıştır** — değerin
**değiştiğini** görürsün. Çünkü saat sen debug ederken bile sayıyor.

> **Adres notu:** `CLINT_BASE` = `0x02000000`. Üstüne offset biniyor:
> `+0x4000` → mtimecmp, `+0xBFF8` → mtime. (`0x02000000`'ın kendisi `msip`,
> yani yazılım kesmesi — onu kullanmıyoruz.) Hepsi `platform.h` satır 71-75'te.

> **Söyleyeceğin cümle:** "Bu bir fonksiyon çağrısı değil, doğrudan donanım
> register'ı. `platform.h`'de `CLINT_BASE` olarak isimli; gerçek kartta bu
> adres `0x44000000` olacak ve kod değişmeyecek."

---

## Senaryo 3 — "Bir saniyeyi 1 saniye beklemeden gör" ⭐ değer kanıtı

**Problem:** ekrana `[tick 10]` basan satıra breakpoint koyarsan **10 kesme
beklemen** gerekir, yani ~30 kez F10/F5.

**Breakpoint:** `main.c` satır **148** (`uint32_t now = g_tick_count;`)

Düştüğünde:
```
-exec set var g_tick_count = 9
```

F5 → bir sonraki kesmede sayaç **10** olur → satır **151**'deki `if` **tutar** →
ekrana `[tick 10] uptime = 1 s` basılır.

> **Söyleyeceğin cümle:** "Değişkeni dışarıdan değiştirip 10 saniye beklemeden
> o dalı test ettim. Gerçek projede 'saat 24 olunca ne oluyor' gibi senaryolar
> böyle test edilir — beklemeden."

**Bu senaryo, debug ortamının neden değerli olduğunun en net kanıtı.
Sunumda öne çıkar.**

---

## Senaryo 4 — "Koşullu breakpoint" (tek F5 ile)

Senaryo 3'ün zarif hali, hiç değişken kurcalamadan.

Satır **151**'deki (`if`) breakpoint'e **sağ tık → Edit Breakpoint →
Expression**:

```
now == 10
```

Artık F5'e **bir kez** basıyorsun. GDB satıra 10 kez uğruyor ama **sadece
koşul tuttuğunda duruyor.**

> **Söyleyeceğin cümle:** "Breakpoint'lere koşul verilebiliyor. 'Sadece sayaç
> 10 olduğunda dur' dedim, tek seferde o ana geldim."

---

## Senaryo 5 — "Kritik satırı bozalım" ⭐ en öğretici

**Yedeğini aldığından emin ol** (`copy main.c main.c.yedek`).

`main.c` satır **87**'yi yorum yap:

```c
/* timer_schedule_next(); */
```

Derle ve çalıştır:
```powershell
mingw32-make
mingw32-make run
```

**Göreceğin:** banner basılır, `Zamanlayici kesmesi aktif...` yazar, sonra
**tam sessizlik.** Hiç `[tick]` satırı yok.

**Sebep:** alarm bir kez çaldı, `g_tick_count` 1 oldu, kimse alarmı yeniden
kurmadı → `wfi` sonsuza kadar uyuyor.

QEMU'dan çık: **Ctrl+A** sonra **X**

**Geri al:**
```powershell
copy main.c.yedek main.c
mingw32-make
```

> **Söyleyeceğin cümle:** "RISC-V zamanlayıcısı tek seferliktir.
> Periyodikliği yazılım sağlar. Bu tek satır, tüm sistemin kalp atışı."

---

## Senaryo 6 — "Hata (exception) nasıl görünür" (opsiyonel)

`trap_handler` iki iş yapıyor: **kesme** (satır 82-93) ve **hata**
(satır 94-108). Şimdiye kadar hep birincisini gördük.

**Breakpoint:** `main.c` satır **99** (`uart_puts("\n*** EXCEPTION ***\n");`)

Normal çalıştır, `main`'de dur, sonra:
```
-exec set var $pc = 0x0
-exec continue
```

Program `0x0` adresinden komut okumaya çalışır → **geçersiz adres** →
işlemci hata fırlatır → `trap_handler`'ın **else** dalına düşer.

```
-exec p/x $mcause
```
Bu kez **`8` ile başlamayan** bir değer (örn. `0x1`). Üst bit **0** →
"bu bir **hata**, kesme değil".

```
-exec p/x $mepc
-exec p/x $mtval
```
`mepc` = hatanın olduğu adres · `mtval` = suçlu adres (`0x0`)

> **Söyleyeceğin cümle:** "`mcause`'un en üst biti kesme ile hatayı ayırıyor.
> Bu dal, gerçek projede çökme sebebini ekrana basıp sistemi durduruyor —
> kör çökme yaşanmıyor."

---

# C.7 Paneller — nerede neye bakacaksın

| Panel | Ne zaman işine yarar |
|---|---|
| **VARIABLES** | Lokal değişkenler (`now`, `reported`). Otomatik dolu |
| **WATCH** | Global ve CSR'lar. Elle ekle: `g_tick_count`, `$mcause`, `$mepc`, `$mie` |
| **CALL STACK** | Senaryo 1'in can alıcı noktası: `trap_handler <- trap_entry` |
| **BREAKPOINTS** | Koşullu breakpoint burada düzenlenir (Senaryo 4) |

> **Not:** WATCH panelinde CSR'lar **onluk** görünür. `$mcause` =
> `-2147483641` yazarsa korkma, bu `0x80000007`'nin onluk hali. Hex istersen
> console'da `-exec p/x $mcause`.

---

# C.8 Kopyala-yapıştır komut listesi

```
-exec p g_tick_count                sayacı oku
-exec p/x $mcause                   kesme mi hata mı
-exec set var g_tick_count = 9      değişkeni dışarıdan değiştir
-exec x/2xw 0x0200bff8              donanım saatine (mtime) doğrudan bak
-exec x/2xw 0x02004000              alarm koluna (mtimecmp) bak
-exec p/x $mepc                     kesilen/hata veren komutun adresi
-exec info registers                tüm register'lar
```

---

# C.9 Breakpoint özeti

| Satır | Ne var | Hangi senaryo |
|---|---|---|
| **63** | `timer_schedule_next` içi | 2 |
| **86** | `g_tick_count++` | 1 |
| **87** | `timer_schedule_next();` — kritik satır | 5 |
| **99** | exception yazdırma | 6 |
| **148** | `now = g_tick_count` | 3 |
| **151** | saniyelik `if` | 4 (koşullu) |

---

# C.10 Çekim sonrası kontrol listesi

- [ ] `main.c` satır 87 yorumdan **çıkarıldı** mı?
- [ ] `copy main.c.yedek main.c` yapıldı mı?
- [ ] `mingw32-make` hatasız derliyor mu?
- [ ] Koşullu breakpoint'ler silindi mi?
- [ ] Arkada QEMU kalmadı mı? → `tools/qemu-stop.ps1`
- [ ] Son doğrulama: `powershell -ExecutionPolicy Bypass -File tools/smoke-test.ps1`
      → **10 / 10 kontrol gecti** beklenir
