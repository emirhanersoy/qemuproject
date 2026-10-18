# KULLANIM.md — Bu ortamı gerçek projelerde kullanmak

> **Bu dosya kimin için?** Bu ortamı devralan, taşıyan veya üstüne gerçek bir
> firmware projesi inşa edecek geliştirici için.
>
> - `aciklama.md` → "bu nedir, neden var" (konuyu hiç bilmeyen biri için)
> - `README.md` → müdür/ekip tarafı: yol haritası, kesme akışı, sorun giderme
> - `CLAUDE.md` → teknik devir-teslim: kararların gerekçeleri, tuzaklar
> - **`KULLANIM.md` (bu dosya)** → **ileriye dönük kullanım:** simülasyonu
>   gerçeğe yaklaştırmak, başka makinelere taşımak, yeni C projesi koymak
>
> Son güncelleme: 2026-10-18

---

## 0. Önce dürüst bir çerçeve

Bugün elinizde olan şey **çalışan bir SiL (Software-in-the-Loop) iskeleti**:
RV32 komut kümesini, CSR'ları ve CLINT zamanlayıcısını gerçek donanımla
**birebir aynı** şekilde çalıştıran, derleme + koşturma + debug + otomatik test
zinciri kurulu bir ortam. Üzerinde şu an çalışan C kodu basit (Hello World +
timer interrupt), ama **ortamın kendisi basit değil** — asıl iş zaten orada.

Bu dosya üç soruyu cevaplıyor:

| Soru | Bölüm |
|---|---|
| Bu "gerçek bir simülasyon" sayılır mı, nasıl daha gerçek olur? | §1 – §2 |
| Başka bir bilgisayarda / Linux'ta / CI'da nasıl çalışır? | §3 – §5 |
| Yarın 50 dosyalı gerçek bir C projesi koyarsam ne değişir? | §6 – §9 |

Her bölümde **bugün hazır olan**, **birkaç saatte yapılabilen** ve
**haftalar süren** işleri ayrı ayrı işaretledim. Müdürünüze bir şey savunurken
bu ayrımı korumanız önemli.

---

## 1. "Gerçek simülasyon" ne demek — bu ortam nerede duruyor

Simülasyon kelimesi tek bir şey değil, bir **merdiven**. Aşağıdaki tabloda
hangi basamakta olduğumuz işaretli:

| Basamak | Ne simüle edilir | Bu ortam | Not |
|---|---|---|---|
| **1. ISA seviyesi** | Komutlar, register'lar, CSR'lar | ✅ **VAR** | `rv32imac` birebir aynı |
| **2. Ayrıcalık/kesme mimarisi** | mtvec/mstatus/mie/mcause/mret | ✅ **VAR** | Birebir aynı |
| **3. Standart çevre birimler** | CLINT (timer), PLIC (harici kesme) | ⚠️ **KISMEN** | CLINT var; PLIC QEMU'da var ama kodda kullanılmıyor |
| **4. Özel çevre birimler** | CoreUARTapb, CoreGPIO, CoreSPI... | ❌ **YOK** | Faz 4 — QEMU'ya cihaz modeli yazmak gerekir (§2.3) |
| **5. Zamanlama doğruluğu** | Komut başına gerçek cycle sayısı | ❌ **YOK** | `-icount` ile yaklaşılabilir (§2.2), FPGA'de birebir olmaz |
| **6. Fiziksel katman** | Saat jitter'ı, ısı, radyasyon (SEU) | ❌ **YOK** | QEMU'nun işi değil, FPGA/kart işi |

### Kritik ayrım: **mantık doğrulaması** vs **donanım doğrulaması**

Bu ortam **mantığı** doğrular, **donanımı** doğrulamaz.

- Bir durum makinesi yanlış duruma geçiyorsa → **burada yakalanır**
- Bir zaman hesabı taşma yapıyorsa → **burada yakalanır**
- Bir kesme içinde paylaşılan değişken bozuluyorsa → **burada yakalanır**
- Bir protokol paketi yanlış kodlanıyorsa → **burada yakalanır**
- SPI'ın chip-select'i 2 cycle erken düşüyorsa → **burada yakalanmaz**
- FPGA dokusu 50 MHz'de timing kapatmıyorsa → **burada yakalanmaz**

Gömülü projelerde hataların büyük çoğunluğu ilk gruptadır. Bu yüzden "gerçek
simülasyon değil" demek yanlış; **"cihaz seviyesinde değil, yazılım seviyesinde
gerçek bir simülasyon"** demek doğru. Simics'in asıl satın alınma sebebi
4. basamaktı — lisans alınamadığı için o basamak bu ortamda yok ve bunu
saklamıyoruz.

---

## 2. Simülasyonu gerçeğe yaklaştırmanın yolları

Aşağıdakiler **artan maliyet** sırasına göre. 2.1'i bugün yapabilirsiniz,
2.4 haftalar sürer.

### 2.1 `platform.h`'yi gerçek tasarımla doğrulamak — **en yüksek değer, en düşük maliyet**

Bu, yapılabilecek **en önemli** iş ve kart gelmeden de yapılabilir: Libero SoC
projesinin **Memory Map raporu** yeterli. Şu an `platform.h` içindeki
`PLATFORM_RTG4_MIV` bloğu **Mi-V referans tasarımlarının tipik değerleri** ve
kodda açıkça öyle işaretli:

```c
#define CLINT_BASE          0x44000000UL   /* MIV_RV32 dahili CLINT        */
#define MTIME_FREQ_HZ       50000000UL     /* Libero'daki SYS_CLK'e gore   */
#define UART_BASE           0x70001000UL   /* CoreUARTapb (tasarima bagli) */
```

Doğrulanacaklar:

| Sabit | Nereden doğrulanır |
|---|---|
| `CLINT_BASE` | MIV_RV32 IP yapılandırma sayfası |
| `UART_BASE` | Libero'da CoreUARTapb'ın APB bus'a bağlandığı adres |
| `RAM_BASE` / boyut | LSRAM / TCM / DDR yerleşimi → `linker.ld`'deki `LENGTH` da güncellenir |
| `MTIME_FREQ_HZ` | Tasarımdaki `SYS_CLK` frekansı |
| `UART_PCLK_HZ` | APB saat frekansı (baud hesabı buna bağlı) |

Bu beş sayı doğrulandığı anda, aynı kaynak kod gerçek donanımda **ilk denemede**
çalışma şansı çok yükselir. Doğrulanmazsa kart geldiğinde "hiçbir şey çıkmıyor"
ile saatler kaybedilir.

> **Önemli:** `MTIME_FREQ_HZ` yanlışsa kod çalışır ama **zamanlar yanlış olur**.
> QEMU'da 10 MHz, RTG4'te 50 MHz varsayılıyor; `main.c` tick periyodunu
> `MTIME_FREQ_HZ / TICK_HZ` ile hesapladığı için bu sayı doğru olduğunda
> 100 ms gerçekten 100 ms olur. Bu, kodda sabit sayı yazmamanın somut getirisi.

### 2.2 Deterministik ve ölçülebilir zamanlama — **yarım gün**

QEMU varsayılan olarak "host hızında" koşar: aynı kod iki çalıştırmada farklı
sürede biter. Test tekrarlanabilirliği için QEMU'nun **komut sayacı** modu var:

```
-icount shift=3,sleep=off
```

Bu, "her komut 2^3 = 8 sanal cycle sürer" demektir ve sanal saati komut
sayısına bağlar. Getirisi:

- Aynı test **her çalıştırmada birebir aynı** sonucu verir (regresyon için altın değer)
- Zamanlama hataları (race condition) tekrar üretilebilir hale gelir
- `-rtc clock=vm` ile birlikte tam deterministik bir sanal makine olur

Sınırı dürüstçe: `shift` tek bir ortalama sayıdır, **gerçek cycle sayısı değil**.
Mi-V'de bir `lw` komutunun kaç cycle sürdüğü bus yüküne ve LSRAM gecikmesine
bağlıdır; QEMU bunu bilmez. Yani `-icount` **tekrarlanabilirlik** verir,
**cycle doğruluğu** vermez.

Makefile'a eklemek için:

```make
# Deterministik kosum (regresyon testleri icin)
QEMU_DETERMINISTIC := -icount shift=3,sleep=off -rtc clock=vm

run-det: $(TARGET).elf
	@"$(QEMU)" $(QEMU_FLAGS) $(QEMU_DETERMINISTIC)
```

### 2.3 Gözlemlenebilirliği artırmak — **yarım gün, çok işe yarar**

QEMU'nun hazır izleme (trace) yetenekleri kullanılmıyor; bunlar gerçek hata
avında çok değerli:

```
-d int,mmu,guest_errors -D qemu-trace.log    # kesmeleri ve hatalari logla
-d in_asm                                    # calisan her komutu yaz (cok buyuk log)
-serial file:serial.log                      # UART'i dosyaya ayir
-monitor telnet:127.0.0.1:4444,server,nowait # calisirken register/bellek sorgula
```

En çok işe yarayanı `-d int`: her kesmede hangi `mcause` ile trap'e girildiğini
yazar. "Kesme neden gelmiyor / neden sürekli geliyor" sorularını dakikalar
içinde çözer.

Ayrıca **QEMU monitor** (`-monitor`) ile çalışan sistemde `info registers`,
`xp /16x 0x80000000` gibi komutlar verilebilir — GDB'ye paralel bir gözlem kanalı.

### 2.4 QEMU'ya gerçek `miv` makine modeli yazmak — **haftalar, Faz 4**

4. basamağa (özel çevre birimler) çıkmanın tek yolu bu. QEMU kaynağında
`hw/riscv/` altına C ile bir `miv` makinesi ve `hw/char/` altına bir
`CoreUARTapb` cihaz modeli yazılır. Yapılacaklar kabaca:

1. QEMU kaynağını klonla, kendi branch'inde çalış
2. `MachineClass` tanımla: RAM tabanı, CLINT adresi, hart sayısı
3. Her çevre birim için `SysBusDevice` türet, `MemoryRegionOps` ile
   `read`/`write` fonksiyonlarını yaz (register davranışı burada modellenir)
4. `-machine miv` ile kullanılabilir hale gelir

Ne zaman değer: **çevre birim yazılımı kritikse.** Örneğin bir SPI sensörünün
init sekansını kart gelmeden doğrulamak istiyorsanız, o sensörün modelini
yazmak tek yol. Ama tek ihtiyacınız UART'a yazı basmaksa bu iş kesinlikle
değmez — mevcut NS16550A yeter.

**Ara yol (daha ucuz):** çevre birimleri QEMU'ya değil, **kodun içine** mock'layın
(§8). Donanım katmanı ayrı dosyada olduğu sürece, testte "yalancı SPI sürücüsü"
bağlamak bir cihaz modeli yazmaktan kat kat ucuz.

### 2.5 Hangisi sizin için? — karar tablosu

| İhtiyaç | Yapılacak |
|---|---|
| "Mantığım doğru mu?" | Zaten var, bugün kullanın |
| "Kart gelince ilk denemede çalışsın" | §2.1 — `platform.h` doğrulaması |
| "Testler CI'da güvenilir koşsun" | §2.2 — `-icount` |
| "Kesme/trap hatası arıyorum" | §2.3 — `-d int` |
| "Çevre birim sürücüsünü kartsız doğrulayacağım" | §8 mock'lar; yetmezse §2.4 |
| "Cycle-accurate zamanlama lazım" | QEMU değil — Libero simülatörü / gerçek kart |

---

## 3. Başka bir bilgisayara taşımak (Windows)

Ortam **taşınabilir olacak şekilde** kuruldu: makineye özgü hiçbir şey kaynak
dosyalarda yok, hepsi `config.mk` içinde ve o dosya git'e girmiyor.

### Tek komutluk kurulum

```powershell
# Yeni makinede, proje klasöründe:
powershell -ExecutionPolicy Bypass -File tools\setup.ps1
```

`tools/setup.ps1` sırayla:

1. QEMU kurar (`winget install SoftwareFreedomConservancy.QEMU`)
2. `xpm` kurar (npm üzerinden — **Node.js önkoşul**)
3. `riscv-none-elf-gcc` + `gdb` kurar (xPack, ~500 MB indirme)
4. Araç yollarını bulup **`config.mk`** üretir
5. Yolları kullanıcı PATH'ine kalıcı ekler
6. `launch.json` ve `c_cpp_properties.json` içindeki toolchain sürümünü düzeltir

Araçlar zaten kuruluysa sadece 4–6 için:

```powershell
powershell -ExecutionPolicy Bypass -File tools\setup.ps1 -SkipInstall
```

### Doğrulama — **her yeni makinede ilk iş**

```powershell
powershell -ExecutionPolicy Bypass -File tools\smoke-test.ps1
# Beklenen: "10 / 10 kontrol gecti" ve çıkış kodu 0
```

Bu betik 10 kontrol yapıyor: derleme, UART banner'ı, platform adı, timer
tick'i, zaman doğruluğu, GDB bağlantısı, `mtvec`, `mcause`, debugger'ın
değişken yazabilmesi, betiğin sonuna kadar koşması. **10/10 geçmiyorsa ortam
hazır değildir** — hangi kontrolün düştüğü ekranda yazar.

### Taşımada çıkabilecek üç sorun

| Belirti | Sebep | Çözüm |
|---|---|---|
| `riscv-none-elf-gcc: command not found` | PATH yeni süreçlere açık, eski terminal görmüyor | Terminali/VSCode'u yeniden başlat |
| F5'te "Unable to start debugging" | `launch.json`'daki toolchain sürümü sabit (`15.2.0-1.1`), derleyici güncellendi | `setup.ps1 -SkipInstall` (adım 4b düzeltir) |
| `missing separator` (Makefile) | Girinti boşlukla yapılmış | Sekme (tab) kullan — `.vscode/settings.json` zorluyor |

### Taşınabilirliği artırmak için önerilen iki adım

**1) `git init` + ilk commit.** `.gitignore` hazır ve doğru: `config.mk`, `*.o`,
`*.elf/.bin/.hex/.map/.lst`, `platform.stamp`, `qemu-out.txt` dışarıda. Yani
depoya sadece kaynak ve betikler girer; her makine kendi `config.mk`'sını
`setup.ps1` ile üretir. Bu, "farklı bilgisayarlarda aynı proje" sorununun
asıl çözümü.

```powershell
git init
git add .
git commit -m "RTG4/Mi-V QEMU SiL ortami - Faz 1"
```

**2) Araç sürümlerini sabitlemek.** `setup.ps1` şu an `@latest` kuruyor; bu,
altı ay sonra kuran kişinin farklı bir GCC alması demektir. Tekrarlanabilirlik
için sürümü sabitleyin:

```powershell
xpm install --global @xpack-dev-tools/riscv-none-elf-gcc@15.2.0-1.1
```

---

## 4. Linux / macOS'ta çalıştırmak

Kaynak kodun hiçbir yeri Windows'a bağlı değil. Windows'a bağlı olan tek şey
**PowerShell yardımcı betikleri** (`tools/*.ps1`).

### Ne değişmeden çalışır

- `startup.S`, `main.c`, `uart.c`, `platform.h`, `riscv_csr.h`, `linker.ld` → **aynen**
- `Makefile` → **aynen** çalışır; içinde `ifeq ($(OS),Windows_NT)` ile `del`/`rm -f`
  seçimi zaten var. Komut `mingw32-make` değil `make` olur.

### Kurulum

```bash
# Debian / Ubuntu
sudo apt install qemu-system-misc gdb-multiarch make
# Toolchain: xPack (platformdan bagimsiz) veya dagitimin paketi
npm install -g xpm
xpm install --global @xpack-dev-tools/riscv-none-elf-gcc@15.2.0-1.1

# macOS
brew install qemu make
# toolchain icin yine xpm
```

Sonra `config.mk`'yı elle yazın (veya `setup.ps1`'in Linux karşılığını yazın):

```make
CROSS := /home/kullanici/.local/xPacks/@xpack-dev-tools/riscv-none-elf-gcc/15.2.0-1.1/.content/bin/riscv-none-elf-
QEMU  := qemu-system-riscv32
```

```bash
make && make run      # cikis: Ctrl+A sonra X
```

### Ne çalışmaz, ne yapılmalı

`tools/*.ps1` betikleri PowerShell'e bağlı. İki seçenek:

- **PowerShell 7 kurmak** (`pwsh`, Linux/macOS'ta çalışır) — betikler büyük
  ölçüde çalışır, ama `winget` kullanan kurulum kısmı çalışmaz (`-SkipInstall` ile atla)
- **Bash karşılıklarını yazmak** — `smoke-test.sh`, `qemu-debug.sh`. Mantık
  kısa: QEMU'yu `-S -gdb tcp::1234` ile başlat, portun açılmasını bekle, GDB'yi
  `tools/smoke.gdb` ile koştur, çıktıda desenleri ara. **`tools/smoke.gdb`
  platformdan bağımsız, aynen kullanılır.**

> **Taşınabilirlik tavsiyesi:** Yeni test betikleri yazarken mantığı **GDB
> betiğine** (`.gdb`) koyun, PowerShell'e değil. `.gdb` her yerde çalışır,
> `.ps1` çalışmaz. Mevcut tasarım zaten bunu yapıyor — bozmayın.

---

## 5. CI / otomatik regresyon

`smoke-test.ps1` **çıkış kodu döndürüyor** (geçerse 0, geçmezse 1). Yani CI'a
bağlanmaya hazır. Windows runner ile GitHub Actions örneği:

```yaml
name: SiL regression
on: [push, pull_request]

jobs:
  smoke:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - name: Ortami kur
        run: powershell -ExecutionPolicy Bypass -File tools/setup.ps1
      - name: Smoke test
        run: powershell -ExecutionPolicy Bypass -File tools/smoke-test.ps1
```

Linux runner daha hızlı ve ucuzdur; onun için §4'teki bash karşılıkları gerekir
(QEMU + toolchain `apt`/`xpm` ile kurulabilir).

**CI için `-icount` kullanın** (§2.2): host yüküne bağlı zamanlama farkları CI'da
"bazen geçen, bazen geçmeyen" testlere yol açar; `-icount` bunu bitirir.

---

## 6. Yeni / daha karmaşık bir C projesi koymak

Bu, sorunuzun en pratik kısmı. Aşağıdakiler **gerçekten değiştirmeniz gereken**
yerler; sırayla.

### 6.1 Kaynak dosya eklemek — `Makefile`'da `OBJS`

Şu an dosya listesi **elle** yazılı:

```make
HDRS     := platform.h riscv_csr.h uart.h
OBJS     := startup.o main.o uart.o
```

Yeni bir `sensor.c` eklediğinizde `OBJS`'e `sensor.o` eklemezseniz **derlenmez
ve linker "undefined reference" verir**. 3 dosyada bu kabul edilebilir, 30
dosyada değil. İlk gerçek projede yapılacak değişiklik:

```make
# Kaynaklari otomatik bul (alt dizinler dahil)
SRCS_C := $(wildcard src/*.c) $(wildcard src/*/*.c)
SRCS_S := $(wildcard src/*.S)
OBJS   := $(SRCS_C:.c=.o) $(SRCS_S:.S=.o)
```

### 6.2 Başlık dosyası bağımlılıkları — **mutlaka düzeltilmeli**

`HDRS` da elle yazılı ve bu **sessiz hata üretir**: listede olmayan bir başlığı
değiştirirseniz make "güncel" der, derlemez, siz eski kodu debug etmeye
çalışırsınız. GCC bunu otomatik çözüyor:

```make
CFLAGS  += -MMD -MP          # her .o yaninda .d bagimlilik dosyasi uret
ASFLAGS += -MMD -MP

# Kurallardaki $(HDRS) kaldirilir:
%.o: %.c Makefile $(PLATFORM_STAMP)
	@echo [CC]  $<
	@"$(CC)" $(CFLAGS) -c -o $@ $<

-include $(OBJS:.o=.d)       # uretilen bagimliliklari dahil et
```

`clean` hedefine `*.d` eklemeyi unutmayın. **Bu, ciddi bir projeye geçerken
yapılacak en önemli Makefile değişikliği.**

### 6.3 Dizin yapısı

Şu an her şey kök dizinde ve objeler de kökte — bu bilinçli bir karardı
(`mkdir`'ın cmd/sh taşınabilirlik sorunundan kaçınmak için). Gerçek projede:

```
src/          main.c, uygulama modulleri
src/drivers/  uart.c, gpio.c, spi.c ...
src/arch/     startup.S, trap.c
include/      platform.h, riscv_csr.h, uart.h
tests/        host'ta kosan birim testleri (§8)
build/        uretilen objeler
```

`build/` kullanacaksanız dizin oluşturmayı taşınabilir yapın — recipe'de `mkdir`
yerine make'in kendi mekanizması:

```make
BUILD := build
$(BUILD)/%.o: %.c | $(BUILD)
	@"$(CC)" $(CFLAGS) -c -o $@ $<
$(BUILD):
	-@$(MKDIR) $(BUILD)

ifeq ($(OS),Windows_NT)
MKDIR := cmd /c mkdir
else
MKDIR := mkdir -p
endif
```

`-include` ile `-I` yollarını da ekleyin: `CFLAGS += -Iinclude`.

### 6.4 Derleme seviyesi — release hedefi

Şu an `-O0 -g3`: debugger'da satır satır adımlama birebir çalışsın diye. Gerçek
projede teslim edilen ikili `-O2` olmalı:

```make
BUILD_TYPE ?= debug
ifeq ($(BUILD_TYPE),release)
OPTFLAGS := -O2 -g
else
OPTFLAGS := -O0 -g3 -gdwarf-4
endif
```

```powershell
mingw32-make BUILD_TYPE=release
```

> **Uyarı:** `-O2`'ye geçtiğinizde `volatile` eksikleri **ortaya çıkar**. `-O0`'da
> çalışan, `-O2`'de bozulan kod neredeyse her zaman eksik `volatile`'dır
> (kesme içinde değişen değişken, MMIO erişimi). `main.c`'deki
> `volatile uint32_t g_tick_count` tam bu yüzden öyle. **Yeni paylaşılan
> değişkenlerde aynı kuralı uygulayın** ve release derlemesini de smoke test'ten
> geçirin.
>
> `BUILD_TYPE` da `platform.stamp` gibi damgalanmalı, yoksa `-O0` objeleriyle
> `-O2` linklenir. Damga mekanizmasını `PLATFORM` için yapıldığı gibi
> kopyalayın (`CLAUDE.md` §6'daki gerekçeye bakın).

### 6.5 Yığın (stack) ve heap boyutu — **karmaşık kodda ilk patlayan yer**

`linker.ld`:

```
STACK_SIZE = 16K;
HEAP_SIZE  = 4K;
RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 8M
```

16 KB yığın, Hello World için bol; derin çağrı zincirleri, büyük yerel diziler
veya kesme içinde iş yapan gerçek bir uygulama için **az olabilir**. Yığın
taşması gömülü sistemlerde en sinsi hatadır: `.bss`'in üstüne yazar, program
anlamsız yerlerde çöker.

Yapılacaklar:

1. `STACK_SIZE`'ı ihtiyaca göre büyütün (örn. `32K`)
2. `linker.ld`'deki `ASSERT` zaten RAM'e sığmayı derleme anında kontrol ediyor —
   **bu satırı kaldırmayın**
3. Yığın taşmasını yakalamak için `_stack_bottom`'a bir **nöbetçi (canary)**
   koyun: `startup.S` içinde bilinen bir desen yazın (örn. `0xDEADBEEF`), ana
   döngüde periyodik kontrol edin. Desen bozulduysa yığın taştı.
4. Gerçek kullanımı ölçün: GDB'de `x/64x _stack_bottom` ile hangi noktaya kadar
   dokunulduğuna bakın (bozulmamış canary deseni = kullanılmamış bölge)
5. `RAM` `LENGTH`'i gerçek RTG4 tasarımındaki LSRAM/DDR boyutuyla hizalayın
   (§2.1) — 8 MB bugün QEMU için seçilmiş bir değer

### 6.6 Kesme işleyicisini genişletmek

Şu an `trap_handler()` tek bir `switch` ile timer kesmesini işliyor. Gerçek
projede birden çok kesme kaynağı olur. Dikkat edilecekler:

**a) `trap_entry` sadece 16 caller-saved register kaydediyor** (64 byte). Bu,
`trap_handler`'ın **normal bir C fonksiyonu** olduğu varsayımına dayanıyor:
callee-saved register'ları o kendisi korur. Bu varsayımı bozmayın —
`trap_handler`'ı `naked` yapmayın, assembly'den doğrudan başka bir şeye
atlamayın.

**b) Periyodikliği sağlayan satır kritiktir:**

```c
case IRQ_M_TIMER:
    g_tick_count++;
    timer_schedule_next();  /* bu satir kaldirilirsa kesme ya bir kez olur
                               ya da sonsuz tetiklenir */
```

RISC-V zamanlayıcısı *one-shot*'tır. Yeni bir kesme kaynağı eklediğinizde de
aynı kural geçerli: **kesme bayrağını temizlemeyi/yeniden kurmayı unutmayın**,
yoksa trap'ten çıkar çıkmaz yeniden girer (sonsuz döngü, sistem kilitlenir).

**c) Kesme içinde iş yapmayın.** Kesme içinde UART'a uzun yazı basmak,
hesaplama yapmak, bekleme döngüsü kurmak gerçek donanımda zamanlama kaçırmaya
yol açar. Desen: kesme bir bayrak/sayaç günceller, ana döngü işi yapar.
`main.c` zaten bunu yapıyor (`g_tick_count++` kesmede, yazdırma ana döngüde) —
bu deseni koruyun.

**d) Harici kesme (PLIC) eklemek.** Timer dışındaki çevre birim kesmeleri
PLIC üzerinden gelir. İki platformda da PLIC var, sadece adresi farklı — yani
`platform.h` deseni aynen uygulanır:

```c
/* PLATFORM_QEMU_VIRT */
#define PLIC_BASE       0x0C000000UL
/* PLATFORM_RTG4_MIV  (Libero'dan dogrulanacak) */
#define PLIC_BASE       0x40000000UL
```

`trap_handler`'da `case IRQ_M_EXTERNAL:` eklenir, PLIC'in claim/complete
register'ları okunarak hangi kaynağın tetiklediği bulunur. Bu, ortamın
genişletilebilirliğinin iyi bir testi ve yarım günlük bir iş.

### 6.7 `printf` ve standart kütüphane

Şu an `-nostdlib -lgcc` ile derleniyor; `printf`, `malloc`, `memcpy`, `strlen`
**yok**. Kendi `uart_puts` / `uart_put_u32` / `uart_put_hex32` fonksiyonları
kullanılıyor. Bu bilinçli: newlib'in `printf`'i hem büyüktür hem de altında
syscall bekler.

Gerçek projede `printf` isteniyorsa üç seçenek:

| Seçenek | Maliyet | Nasıl |
|---|---|---|
| **Kendi mini printf'iniz** (önerilen) | ~200 satır | `%d %u %x %s %c` yeter; tam kontrol, küçük boyut |
| **Hafif üçüncü parti** | düşük | `mpaland/printf` gibi tek dosyalı, bare-metal için yazılmış implementasyonlar |
| **newlib-nano** | orta | `-nostdlib`'i kaldır, `--specs=nano.specs` ekle, **syscall stub'larını yaz** |

newlib seçerseniz en az şu stub'lar gerekir — yoksa linker hata verir:

```c
int _write(int fd, const char *buf, int len);  /* UART'a yonlendir */
void *_sbrk(ptrdiff_t incr);                   /* heap: _heap_start.._heap_end */
int _close(int), _lseek(...), _read(...), _fstat(...), _isatty(int);
```

`_sbrk` için `linker.ld` zaten `_heap_start` / `_heap_end` sembollerini
tanımlıyor — tam bu amaçla konuldu. Ama `HEAP_SIZE` şu an **4K**; `malloc`
gerçekten kullanılacaksa büyütün.

> **Gömülü tavsiyesi:** Uzay/kritik projelerde `malloc` genelde **yasaktır**
> (parçalanma, öngörülemeyen süre). Statik tahsis veya sabit boyutlu havuz
> (pool) tercih edin. RTG4 bir uzay FPGA'i olduğu için ekibinizin bu konuda bir
> kodlama standardı olması muhtemel — sormaya değer.

### 6.8 Floating point

`-mabi=ilp32` ve `rv32imac`: **donanım FPU yok**, `float`/`double` işlemleri
yazılımla emüle edilir (`libgcc` içinden). Çalışır ama yavaştır ve kod boyutunu
büyütür. Mi-V yapılandırmasında FPU varsa (`MIV_RV32` seçeneğe bağlı olarak
`F`/`D` eklenebilir) `ARCHFLAGS` güncellenir:

```make
ARCHFLAGS := -march=rv32imafc_zicsr_zifencei -mabi=ilp32f
```

**Dikkat:** FPU açılırsa `trap_entry` **floating-point register'ları da
kaydetmek zorundadır** (`f0`-`f7`, `f10`-`f17` caller-saved). Şu anki
`trap_entry` bunu yapmıyor — FPU'lu bir yapılandırmaya geçerken bu bir **sessiz
bozulma** kaynağıdır: kesme, kesilen kodun float değerini bozar. Unutmayın.

### 6.9 C++ kullanmak

Mümkün ama ek iş gerektirir: `startup.S`'e global constructor'ları çağıran döngü
(`.init_array` üzerinde yürüme) eklenmeli, `-fno-exceptions -fno-rtti` ile
derlenmeli (exception'lar bare-metal'de ciddi runtime desteği ister),
`__cxa_*` stub'ları yazılmalı. Uzay projelerinde genelde C tercih edilir;
C++ kararı ekip standardına bağlı.

---

## 7. Yeni bir çevre birim sürücüsü eklemek — adım adım örnek

**Bu, projenin en önemli kuralı ve bozulmaması gereken desen:** uygulama kodu
asla çıplak adres kullanmaz. Örnek olarak bir GPIO ekliyoruz.

### Adım 1 — Adresi `platform.h`'ye koy, **her iki platform için**

```c
/* --- PLATFORM_QEMU_VIRT blogunda --- */
#define GPIO_BASE           0x10060000UL   /* QEMU virt: SiFive GPIO */

/* --- PLATFORM_RTG4_MIV blogunda --- */
#define GPIO_BASE           0x70002000UL   /* CoreGPIO - Libero'dan DOGRULANACAK */
```

QEMU'da karşılığı olmayan bir çevre birim için de ikisini de tanımlayın;
QEMU tarafı mock (§8) olabilir. Önemli olan **kodun iki hedefte de derlenmesi**.

### Adım 2 — Sürücüyü ayrı dosyaya yaz: `gpio.c` + `gpio.h`

`uart.c`'deki deseni kopyalayın: iki platform için farklı register düzeni
`#if defined(...)` ile seçilir, **arayüz (`gpio.h`) aynı kalır**. Uygulama kodu
hangi platformda olduğunu bilmez.

### Adım 3 — `Makefile`'a ekle

`OBJS`'e `gpio.o` (veya §6.1'deki `wildcard`'a geçtiyseniz otomatik).

### Adım 4 — **İki hedef için de derle**

```powershell
mingw32-make
mingw32-make PLATFORM=PLATFORM_RTG4_MIV
```

İkisi de derlenmiyorsa desen bozulmuş demektir. `platform.stamp` mekanizması
sayesinde `PLATFORM` değişince tüm objeler yeniden derlenir — bu damga bir
hatayı önlemek için konuldu (eskiden make "Nothing to be done" deyip QEMU
ikilisini RTG4 derlemesi gibi bırakıyordu), **kaldırmayın**.

### Adım 5 — Smoke test'e bir kontrol ekle

`tools/smoke-test.ps1` içinde `Check` fonksiyonu var; UART çıktısında yeni bir
desen arayan bir satır eklemek bir dakikalık iş:

```powershell
Check "gpio-init" ($uart -match 'GPIO ready') "gpio surucusu basladi"
```

Böylece kontrol sayısı 10'dan 11'e çıkar ve regresyon kapsamı büyür.

---

## 8. Birim testleri — kodu host'ta koşturmak

QEMU uçtan uca test eder ama yavaştır ve her küçük fonksiyon için ağırdır.
Gömülü projelerde standart yaklaşım: **donanıma dokunmayan mantığı host'ta
(x86, normal gcc ile) derleyip test etmek.** Bu, saniyeler içinde koşan yüzlerce
test demektir.

Ön koşul: **mantık ile donanım erişimi ayrı dosyalarda olmalı.** Yani
`protocol_parse_frame()` gibi saf fonksiyonlar `uart_putc()` çağırmamalı.
Bu ayrım bugünkü kodda kısmen var (`uart.c` ayrı), yeni kodda bilinçli korunmalı.

Yapı:

```
tests/
  mock_platform.h     MMIO32'yi gercek adres yerine bir diziye yonlendirir
  test_protocol.c     saf mantik testleri
  Makefile.host       normal gcc ile derler, host'ta kosar
```

`mock_platform.h` fikri basit: `platform.h`'deki `MMIO32(a)` makrosunu test
derlemesinde bir sahte bellek dizisine bağlarsınız. Böylece sürücü kodu
"register'a yazdı" sanır, siz de dizide ne yazıldığını kontrol edersiniz —
kesme ve zamanlayıcı mantığı bile kartsız/QEMU'suz test edilebilir hale gelir.

Test çerçevesi olarak Unity veya basit `assert` yeter; bare-metal dünyasında
Unity + CMock yaygın.

> **Not:** Bu iş bugüne kadar yapılmadı ve istenmedi. Gerçek bir projeye
> geçerken en yüksek getirili eklemelerden biri: QEMU smoke test'i
> "sistem ayakta mı" sorusunu cevaplar, birim testleri "mantık doğru mu"
> sorusunu — ikisi farklı sorular.

---

## 9. Gerçek donanıma geçiş (Faz 3) — ne değişir, ne değişmez

Kart geldiğinde:

**Değişmeyenler:** `main.c`, `startup.S`, `uart.c`, `linker.ld` (RAM boyutu
hariç), `Makefile`, GDB arayüzü, `.vscode` yapısı. Komut:

```powershell
mingw32-make PLATFORM=PLATFORM_RTG4_MIV
```

**Değişenler:**

| Konu | QEMU | Gerçek RTG4 |
|---|---|---|
| Yükleme | `-kernel firmware.elf` | FlashPro + JTAG, veya `firmware.hex` → eNVM |
| Debug sunucusu | QEMU'nun dahili gdbserver'ı (`localhost:1234`) | OpenOCD (veya SoftConsole) |
| `launch.json` | `miDebuggerServerAddress` → QEMU | → OpenOCD portu, farklı `preLaunchTask` |
| `.data` kopyalama | atlanır (`_data_load_start == _data_start`) | **gerçekten çalışır** (eNVM → RAM) |
| Adresler | `platform.h` QEMU bloğu | `platform.h` RTG4 bloğu — **§2.1 doğrulaması burada karşılığını verir** |

`firmware.hex` **zaten üretiliyor** (Makefile'ın link adımında), yani Libero /
eNVM programlama akışına bağlanmaya hazır.

Başlangıçta hiçbir çıktı gelmezse sırayla: (1) `UART_BASE` doğru mu,
(2) `UART_PCLK_HZ` ve baud hesabı doğru mu, (3) terminal 115200 8N1 mi,
(4) `MTIME_FREQ_HZ` doğru mu. Dördü de §2.1'de doğrulanacak listede.

---

## 10. Özet kontrol listeleri

### Yeni makineye kurarken

- [ ] `tools\setup.ps1` çalıştır
- [ ] `tools\smoke-test.ps1` → **10/10 ve exit 0** görmeden devam etme
- [ ] F5 ile VSCode debug'ı dene (`main`'de durmalı)
- [ ] `mingw32-make PLATFORM=PLATFORM_RTG4_MIV` → derlenmeli

### Herhangi bir değişiklikten sonra

- [ ] `mingw32-make` → uyarı olmadan derlenmeli (`-Wall -Wextra` açık)
- [ ] `mingw32-make PLATFORM=PLATFORM_RTG4_MIV` → **ikinci hedef de derlenmeli**
- [ ] `tools\smoke-test.ps1` → 10/10. Geçmiyorsa hangi kontrolün düştüğünü
      söyle, "çalışıyor" deme.

### Gerçek bir projeye geçerken (öncelik sırasıyla)

- [ ] `git init` + ilk commit
- [ ] `-MMD -MP` otomatik başlık bağımlılıkları (§6.2) — **sessiz hata kaynağı**
- [ ] `wildcard` ile kaynak dosya listesi (§6.1)
- [ ] `STACK_SIZE` gözden geçir + canary (§6.5)
- [ ] `BUILD_TYPE=release` hedefi, `-O2` ile smoke test (§6.4)
- [ ] `platform.h`'yi Libero memory map raporundan doğrula (§2.1)
- [ ] Birim test iskeleti + mock platform (§8)
- [ ] CI'a bağla, `-icount` ile deterministik koşum (§2.2, §5)

### Bu kuralları bozma

1. **Uygulama kodunda çıplak adres yok** — her adres `platform.h`'de isimli
2. **Her sürücü ayrı `.c` dosyasında**, arayüzü platformdan bağımsız
3. **Her değişiklik iki platform için de derlenir**
4. **Kesme içinde paylaşılan her değişken `volatile`**
5. **Kesme içinde iş yapılmaz** — bayrak set edilir, ana döngü işler
6. **Zamanlayıcıyı her kesmede yeniden kur** (one-shot)
7. **`linker.ld`'deki `ASSERT` ve `platform.stamp` mekanizması kaldırılmaz**
8. **Kod dosyalarındaki Türkçe yorumlar ASCII** (ı/ş/ğ/ç/ö/ü yok); `.md`
   dosyaları tam Türkçe/UTF-8
9. **Test mantığı `.gdb` betiğine yazılır**, `.ps1`'e değil (taşınabilirlik)
10. **Değişiklikten sonra smoke test koşturulur ve sonuç dürüstçe raporlanır**
