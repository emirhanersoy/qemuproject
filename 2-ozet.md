# 2-ozet.md — Demo, basitçe

> `2.md` çok ayrıntılıydı. Bu dosya **sadece yapacağın şeyleri** sırayla
> veriyor. Her adımda: **ne yazacaksın**, **ne göreceksin**, **ne
> söyleyeceksin**.

---

## Önce: hazırlık (demodan önce)

```powershell
powershell -ExecutionPolicy Bypass -File tools\smoke-test.ps1
```

`10 / 10 kontrol gecti` görmeden demoya başlama.

```powershell
tools\qemu-stop.ps1              # arkada kalan QEMU'yu kapat
copy main.c main.c.yedek         # kodu bozacağız, yedek al
```

Sonra **VSCode'u yeniden başlat** (araçları görsün) ve terminal yazısını
büyüt: **Ctrl + `+`**

---

# BÖLÜM 1 — Derleme (3 dakika)

## Adım 1.1 — Projeyi aç

VSCode → **File → Open Folder** → `qemuproject` klasörü

> Tek dosya değil **klasörü** aç. F5 ve Ctrl+Shift+B ancak böyle çalışır.

## Adım 1.2 — Hangi derleyiciyi kullanıyoruz

Terminal aç (**Ctrl + `**) ve yaz:

```powershell
mingw32-make info
```

**Göreceksin:**
```
PLATFORM = PLATFORM_QEMU_VIRT
CC       = C:\Users\...\riscv-none-elf-gcc
QEMU     = C:\Program Files\qemu\qemu-system-riscv32.exe
```

**Söyle:**
> "Derleyicimiz `riscv-none-elf-gcc`. Normal gcc değil — normal gcc bu
> bilgisayar için kod üretir, bize RISC-V için kod üreten bir derleyici
> lazım. İsmindeki `riscv` bu yüzden var."

## Adım 1.3 — Derle

**Ctrl + Shift + B**

**Göreceksin:**
```
[AS]  startup.S
[CC]  main.c
[CC]  uart.c
[LD]  firmware.elf
             RAM:       22544 B         8 MB      0.27%
   text    data     bss
   2042       0   20492
Hazir: firmware.elf + .bin .hex .map .lst
```

**Söyle:**
> "Üç dosya ayrı ayrı derlendi, sonra birleştirildi. Kodumuz 2 kilobayt,
> 8 megabaytlık belleğin yüzde 0.27'si. Yani ortam neredeyse hiç yer
> kaplamıyor."

## Adım 1.4 — RTG4 hedefi için de derle (güçlü an)

```powershell
mingw32-make clean
mingw32-make PLATFORM=PLATFORM_RTG4_MIV
```

**Göreceksin:** Hata yok, derlendi.

**Söyle:**
> "Aynı kodu bu kez gerçek RTG4 için derledim. Tek değişen şey komut
> satırındaki bir parametre. `main.c`'nin tek satırı değişmedi.
>
> Bunu QEMU'da çalıştıramam, çünkü RTG4'ün adresleri QEMU'da yok. Ama
> derlendiğini göstermek önemli: kart geldiğinde kodu yeniden yazmaya
> gerek olmayacak."

**Sonra geri dön — bunu unutma:**
```powershell
mingw32-make clean
mingw32-make
```

---

# BÖLÜM 2 — Çalıştırma (3 dakika)

## Adım 2.1 — Önce şunu söyle

**Söyle:**
> "Bu kod **bu bilgisayarın işlemcisinde koşmuyor.** QEMU, RISC-V
> komutlarını okuyup bu bilgisayarın anlayacağı koda çevirerek
> çalıştırıyor. Yani ortada tamamen sanal bir RISC-V bilgisayarı var."

## Adım 2.2 — Çalıştır

```powershell
mingw32-make run
```

**Göreceksin:**
```
===========================================
 Hello, World!
 RTG4 / Mi-V RV32 firmware - QEMU SiL
===========================================
 Platform   : QEMU riscv32 'virt'
 RAM base   : 0x80000000
 CLINT base : 0x02000000
 UART base  : 0x10000000
 mtime freq : 10000000 Hz
 Tick       : 100 ms
-------------------------------------------
Zamanlayici kesmesi aktif. Sayac ilerliyor...

[tick 10] uptime = 1 s
[tick 20] uptime = 2 s
[tick 30] uptime = 3 s
```

## Adım 2.3 — **5-6 saniye bekle**

Satırların akmasına izin ver. Acele etme — bu, demonun en ikna edici anı.

**Söyle:**
> "Üstteki adresler `platform.h`'den geliyor — kod kendi ayarlarını
> yazdırıyor, yani yanlış hedefi çalıştırsam ilk satırlardan anlarım.
>
> Alttaki satırlar asıl önemli kısım. Bunlar bir döngünün saymasıyla
> oluşmuyor. İşlemci şu an **uyuyor**. Her 100 milisaniyede bir alarm
> çalıyor, işlemci uyanıyor, sayıyor, her onuncu alarmda bir satır basıyor.
>
> Yani ekrandaki her satır **10 tane gerçek donanım kesmesinin** sonucu.
> Üç satır çıktıysa gerçekten üç saniye geçti."

## Adım 2.4 — Çık

**Ctrl + A** (tuşları bırak) sonra **X**

**Söyle:**
> "QEMU'dan çıkış Ctrl+A sonra X. Ctrl+C işe yaramıyor, çünkü onu QEMU
> simüle edilen makineye iletiyor."

---

# BÖLÜM 3 — Debug (6 dakika)

## Adım 3.1 — Nasıl çalıştığını anlat (çizerek)

```
   VSCode                      QEMU
  ┌──────────┐                ┌─────────────────┐
  │   GDB    │◄──── TCP ─────►│  Sanal işlemci  │
  │ (röntgen)│    port 1234   │  + sunucu       │
  └──────────┘                └─────────────────┘
```

**Söyle:**
> "QEMU'nun içinde bir sunucu var. 'Şu register'ı oku', 'şurada dur' gibi
> istekleri kabul ediyor.
>
> Diğer tarafta GDB var — o da `firmware.elf` dosyasını okuyup hangi
> adresin hangi C satırı olduğunu biliyor. VSCode bu ikisini birleştirip
> bize grafik arayüz gösteriyor.
>
> **Önemli:** Bu yapı gerçek kartta da aynı. Kart geldiğinde QEMU'nun
> yerine JTAG kablosu gelecek, GDB ve VSCode tarafı **değişmeyecek**."

## Adım 3.2 — Breakpoint koy ve F5

`main.c` **satır 132**'nin (`uint32_t reported = 0;`) soluna tıkla →
**kırmızı nokta**

**F5**

**Göreceksin:** Kod `main` içinde durdu, satır **sarı**.

**Söyle:**
> "F5'e bastım, arka planda kod derlendi, QEMU başladı, GDB bağlandı ve
> `main` içinde durdu. Sarı satır şu an çalışmak **üzere** olan satır —
> henüz çalışmadı."

## Adım 3.3 — Sol paneldeki 4 bölümü göster

| Panel | Ne gösteriyor | Ne söyle |
|---|---|---|
| **VARIABLES** | Değişkenler + **Registers** | "Yerel değişkenler ve işlemcinin register'ları" |
| **WATCH** | İstediğin şeyleri sürekli izleme | "Buraya ne eklersem sürekli takip ediyor" |
| **CALL STACK** | "Buraya nasıl geldim" | "Şu an sadece `main` var" |
| **BREAKPOINTS** | Koyduğun duraklar | "Hepsi burada listeli" |

## Adım 3.4 — WATCH paneline şunları ekle

`+` düğmesiyle:

```
g_tick_count
$mtvec
$mcause
$mie
```

**Söyle:**
> "`g_tick_count` normal bir değişken. `$` ile başlayanlar işlemcinin
> **ayar register'ları** — kesme sisteminin kontrol düğmeleri. Gömülü
> debug'ın normal debug'dan ayrıldığı yer burası."

> ⚠️ **Mutlaka söyle:** "Bunlar panelde **onluk sayı** olarak görünüyor.
> `-2147483641` gibi bir şey görürseniz şaşırmayın, o `0x80000007`'nin
> onluk hali."

## Adım 3.5 — Adımlama düğmeleri

| Tuş | Ne yapar |
|---|---|
| **F5** | Sonraki durağa kadar tam hızda koş |
| **F10** | Bir satır ilerle (fonksiyonun içine girmeden) |
| **F11** | Bir satır ilerle (fonksiyonun **içine girerek**) |
| **Shift+F11** | Bu fonksiyondan çık |
| **Shift+F5** | Debug'ı bitir |

**Göster:** F10 ile iki satır ilerle, sonra `uart_init()` satırında
**F11** → `uart.c` dosyası açılır. **Shift+F11** → geri döner.

**Söyle:**
> "F11 fonksiyonun içine girdi ve `uart.c` dosyası kendiliğinden açıldı.
> Debugger hangi kodun hangi dosyada olduğunu biliyor."

## Adım 3.6 — En etkileyici tek şey

Aşağıdaki panel **Debug Console** (alt tarafta). Şunu yaz:

```
-exec p/x $mtvec
```
→ `0x8000007c`

```
-exec p/x &trap_entry
```
→ `0x8000007c`

**Söyle:**
> "İkisi **aynı**. Soldaki işlemcinin 'kesme olunca nereye gideyim'
> register'ı. Sağdaki `startup.S`'teki fonksiyonumuzun adresi.
>
> Yani `startup.S`'teki kesme kurulumu gerçekten çalışmış. Bunu kodu gözle
> okuyarak değil, **canlı işlemciden okuyarak** doğruladım. Debug'ın
> gömülü taraftaki değeri tam bu."

> **Not:** Debug Console'da komutların başına **`-exec`** yazmak şart.

---

# BÖLÜM 4 — Interrupt (5 dakika)

## Adım 4.1 — Önce nasıl çalıştığını anlat

**Söyle (alarm benzetmesiyle):**
> "Kesme bir **alarm** gibi. Program normal akarken alarm çalıyor, program
> aniden durup başka bir fonksiyona atlıyor, orada işini yapıyor, sonra
> **kaldığı yere geri dönüyor**.
>
> Bizim alarmımız her 100 milisaniyede çalıyor."

Üç şartı söyle:
> "Alarmın çalması için üç şey gerekiyor: zamanı gelmiş olmalı, bu alarm
> türü izinli olmalı, ve genel olarak alarmlar açık olmalı. `main.c`'deki
> `timer_start()` fonksiyonunda tam bu üç satır var."

Sonra **en kritik şeyi** söyle:
> "RISC-V'nin alarmı **tek seferlik**. Telefondaki alarmın 'her gün
> tekrarla' seçeneği kapalı gibi. Çalar, susar, biter. Her çalışında
> **elle yeniden kurmak** gerekiyor. Bunu yapan satır `main.c` satır 87."

**Göster:** `main.c` satır 87:
```c
timer_schedule_next();   // alarmı yeniden kur
```

## Adım 4.2 — Kesmeyi canlı yakala

**Shift+F5** ile önceki oturumu kapat.

`main.c` **satır 79**'a (`uint32_t mcause = csr_read(mcause);`) breakpoint
koy.

**F5** → `main`'de durur.
**F5** tekrar → **kesme fonksiyonunun içinde durur.**

**Söyle:**
> "Hiçbir şey yapmadım, sadece 'devam et' dedim ve kesme fonksiyonunun
> içinde durdu. Çünkü alarm çaldı.
>
> Dikkat: `main`'de hiçbir yerde `trap_handler()` çağrısı **yok**. Buraya
> bizi donanım getirdi."

## Adım 4.3 — Neden buradayız

**F10** ile bir satır ilerle, sonra Debug Console:

```
-exec p/x $mcause
```
→ `0x80000007`

**Söyle:**
> "İşlemci bize **neden** buraya geldiğini söylüyor. `0x80000007`:
> en baştaki 8, 'bu bir alarm, hata değil' demek. Sondaki 7 de
> 'zamanlayıcı alarmı' demek.
>
> Eğer burada `0x00000002` gibi bir şey görsem, baştaki 8 olmadığı için
> 'bu bir hata' anlardım."

## Adım 4.4 — Call Stack — **en öğretici an**

**CALL STACK** paneline bak:

```
trap_handler()   main.c:79
trap_entry()     startup.S:114
```

**Söyle:**
> "İşte az önce anlattığımın kanıtı. Alarm çaldığında donanım bizi
> **`startup.S`**'teki `trap_entry`'ye attı — o assembly dosyası. Oradan
> da C fonksiyonumuza geçtik.
>
> Debugger ikisini birlikte gösteriyor. Yani assembly ve C katmanları
> arasında kesintisiz gezinebiliyoruz."

**Göster:** `trap_entry` satırına tıkla → `startup.S` açılır.

## Adım 4.5 — Alarmın tekrarladığını göster

**F5**'e iki kez daha bas → her seferinde aynı yere düşüyor.

```
-exec p g_tick_count
```
→ sayı her seferinde artıyor.

**Söyle:**
> "Her seferinde tekrar çalıyor ve sayaç ilerliyor. Yani alarm gerçekten
> periyodik."

## Adım 4.6 — Debugger ile müdahale

```
-exec set var g_tick_count = 9
```

Sonra `main.c` **satır 154**'e breakpoint koy, satır 79'dakini kaldır,
**F5**.

**Göreceksin:** Yazdırma satırında durdu, `now` = 10.

**Söyle:**
> "Normalde yazdırma satırına ulaşmak için 10 alarm beklemek gerekirdi.
> Ben sayacı 9 yaptım, bir sonraki alarm 10'a çıkardı ve doğrudan oraya
> düştük.
>
> Yani sadece izlemiyoruz, **müdahale** de ediyoruz. Gerçek projede çok
> işe yarıyor: bir hata ancak sayaç taştığında oluyorsa, 4 milyar alarm
> beklemek yerine sayacı taşmanın bir eksiğine ayarlıyorsun."

## Adım 4.7 — Kodu kasıtlı boz (en etkili an)

**Shift+F5** ile debug'ı kapat.

`main.c` **satır 87**'yi yorum yap:
```c
            /* timer_schedule_next(); */
```

```powershell
mingw32-make
mingw32-make run
```

**Göreceksin:** Banner basılıyor, sonra **hiçbir şey gelmiyor.**

**Söyle:**
> "Tek satır sildim ve sistem sustu. Tek bir satır bile gelmiyor.
>
> Ne oldu: alarm çaldı, fonksiyon çalıştı, ama alarmı yeniden kurmadığı
> için sistem sonsuza kadar aynı alarmı işliyor. `main`'e hiç
> dönemiyor, o yüzden hiçbir şey yazdıramıyor.
>
> **Gömülü sistemlerde hatalar tam böyle görünür:** çökme yok, hata
> mesajı yok, sadece sessizlik. Bu ortamın değeri de burada — bu hatayı
> kart beklemeden saniyeler içinde bulup düzeltebiliyorsun."

**Satırı geri aç**, derle, çalıştığını göster:
```powershell
mingw32-make
mingw32-make run
```

---

# BÖLÜM 5 — Kapanış ve temizlik

## Kapanış cümlesi

**Söyle:**
> "Özetleyelim: derledik, çalıştırdık, debugger'ı bağladık, kesme
> ayarlarının doğru kurulduğunu canlı doğruladık, kesmeyi yakalayıp içine
> girdik, sonunda da kodu kasıtlı bozup hatanın nasıl göründüğünü
> gösterdik.
>
> Bu akışın tamamı gerçek kartta da aynı kalacak — sadece QEMU'nun yerine
> gerçek çip gelecek."

## Temizlik — **atlamayın**

- [ ] **Shift+F5** ile debug kapalı mı
- [ ] `tools\qemu-stop.ps1` çalıştırıldı mı
- [ ] **Adım 4.7'deki `timer_schedule_next();` satırı geri açıldı mı?**
- [ ] Adım 1.4'ten sonra son derleme QEMU hedefinde mi?
      (`mingw32-make clean` + `mingw32-make`)
- [ ] Breakpoint'ler temizlendi mi (BREAKPOINTS panelinde "Remove All")
- [ ] Kod yedekle aynı mı: `fc main.c main.c.yedek`
- [ ] **Son kontrol:** `tools\smoke-test.ps1` → **10/10**

Her şey yolundaysa `main.c.yedek` silinebilir.

---

# Kopya kâğıdı

## Komutlar

```powershell
mingw32-make              # derle
mingw32-make run          # çalıştır (çıkış: Ctrl+A sonra X)
mingw32-make info         # hangi araçlar kullanılıyor
mingw32-make clean        # temizle
tools\qemu-stop.ps1       # arkada kalan QEMU'yu kapat
```

## VSCode tuşları

| Tuş | İş |
|---|---|
| **Ctrl+Shift+B** | Derle |
| **Ctrl + `** | Terminal |
| **F9** | Breakpoint koy/kaldır |
| **F5** | Debug başlat / devam |
| **F10** | Bir satır ilerle |
| **F11** | Fonksiyonun içine gir |
| **Shift+F5** | Debug'ı bitir |

## Debug Console (başına `-exec` şart)

```
-exec p/x $mtvec              # kesme vektörü  -> 0x8000007c
-exec p/x &trap_entry         # fonksiyon adresi -> aynı olmalı
-exec p/x $mcause             # kesme nedeni   -> 0x80000007
-exec p g_tick_count          # sayaç
-exec set var g_tick_count = 9   # değer yaz
```

## Breakpoint koyulacak satırlar (`main.c`)

| Satır | Ne için |
|---|---|
| **132** | `main` başı — ilk debug denemesi |
| **79** | **Kesme fonksiyonu** — Bölüm 4'ün ana noktası |
| **87** | Alarmı yeniden kuran satır (bozma denemesi) |
| **154** | Yazdırma satırı |

---

# Bir şey ters giderse

| Belirti | Çözüm |
|---|---|
| `riscv-none-elf-gcc: command not found` | **VSCode'u yeniden başlat** |
| F5 → "Unable to start debugging" | `tools\setup.ps1 -SkipInstall` |
| QEMU penceresi açılıp kapanıyor | `tools\qemu-stop.ps1`, sonra tekrar F5 |
| `0x00001000 in ?? ()` görünüyor | **Normal.** Devam et, `main`'de duracak |
| QEMU'dan çıkamıyorum | **Ctrl+A**, bırak, **X** |
| Breakpoint tetiklenmiyor | **Ctrl+Shift+B** ile derle, tekrar F5 |
| Watch'ta register negatif sayı | **Normal** — onluk gösterim |
| GDB kodlama uyarısı veriyor | **Zararsız**, yoksay |
| F10 sürekli aynı iki satır arası | **Normal** — yazdırma 10 turda 1 kez olur. **F5 kullan** |

> Demo sırasında kodu **sadece** `main.c` satır 118'deki yazıda
> (`Hello, World!`) değiştir. Orası en güvenli nokta — derlemeyi kıramaz.
