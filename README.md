# RTG4 / Mi-V RV32 — QEMU tabanlı Software-in-the-Loop (SiL) ortamı

Fiziksel RTG4 kartı gelmeden önce, RTG4 üzerinde çalışacak RISC-V firmware'ini
VSCode'da yazıp derleyip QEMU'da çalıştırmak ve adım adım debug etmek için
kurulmuş geliştirme ortamı.

**Durum:** çalışıyor. `tools/smoke-test.ps1` ile 10/10 otomatik kontrol geçiyor.

> Bu dosya projeyi **insanlara** anlatır. Projeyi devralacak bir Claude Code
> oturumu için hazırlanmış teknik devir-teslim dosyası ayrıdır: **`CLAUDE.md`**
> — mevcut durum, araç yolları, tasarım gerekçeleri, sert yoldan öğrenilen
> tuzaklar ve sıradaki fazlar orada. Claude Code onu oturum başında otomatik okur.

---

## 1. Önce dürüst bir çerçeve: QEMU'da "RTG4" diye bir makine yok

Bu projeyi anlamanın anahtarı şu ayrımda:

| Katman | Gerçek donanım | Bu ortam |
|---|---|---|
| Çip | **RTG4** — Microchip'in radyasyona dayanıklı uzay FPGA'i | — (FPGA simüle edilmiyor) |
| İşlemci | **Mi-V** (örn. `MIV_RV32`) — FPGA içine yerleştirilen RISC-V *soft-core* | `qemu-system-riscv32 -machine virt` |
| Komut kümesi (ISA) | RV32I + M, A, C | **Birebir aynı:** `rv32imac` |
| Zamanlayıcı | Standart RISC-V **CLINT** (`mtime`/`mtimecmp`) | **Birebir aynı mantık**, farklı taban adres |
| Seri port | `CoreUARTapb` (Libero'da tanımlanır) | NS16550A |

RTG4 bir **FPGA**'dir; içinde hazır bir CPU yoktur. Mi-V, Libero SoC ile FPGA
dokusuna sentezlenen bir RISC-V çekirdeğidir. QEMU'nun RTG4 veya Mi-V makine
modeli **yoktur** ve bir gecede yazılamaz.

Buna karşılık yazılımın **%90'ı** için fark etmez, çünkü:

- **Komut kümesi aynı.** Derleyici `rv32imac` kodu üretir; QEMU da Mi-V de aynı
  komutları çalıştırır. Algoritmalarınız, veri yapılarınız, protokol
  katmanlarınız, matematik kodunuz birebir aynı davranır.
- **Kesme mimarisi aynı.** `mtvec`, `mstatus`, `mie`, `mcause`, `mret` ve CLINT
  (`mtime`/`mtimecmp`) RISC-V standardıdır — Mi-V'de de aynen bunlar var.
  Sadece CLINT'in taban adresi farklı (QEMU `0x0200_0000`, Mi-V `0x4400_0000`).

**Farklı olan:** çevre birimlerin (UART, GPIO, SpaceWire, CAN...) adresleri ve
register düzenleri. Çözüm, bu projenin merkezinde duran tasarım kararı:

> Uygulama kodu **hiçbir zaman** çıplak adres kullanmaz. Tüm adresler
> `platform.h` içinde isimlendirilmiştir. Hedef değiştirmek = tek bir
> `-D` tanımı değiştirmek.

```
mingw32-make                              # QEMU için derler (varsayılan)
mingw32-make PLATFORM=PLATFORM_RTG4_MIV   # gerçek RTG4 için derler
```

`main.c` içindeki kesme mantığının tek satırı bile değişmez. Kart geldiğinde
yapılacak iş, `platform.h`'deki RTG4 bloğundaki adresleri Libero'nun ürettiği
memory map raporuyla doğrulamaktan ibarettir.

**Bu ortamın yapabildiği:** uygulama mantığı, kesme/zamanlayıcı mantığı, zaman
hesapları, durum makineleri, protokol kodu, birim testleri, regresyon testleri.

**Bu ortamın yapamadığı:** gerçek çevre birim davranışı, FPGA doku gecikmeleri,
saat/ısı/radyasyon etkileri, tam çevrim-doğru (cycle-accurate) zamanlama.
Bunlar kart geldiğinde donanımda doğrulanmak zorunda. (Intel Simics'in
getirisi de tam buydu: cihaz modelleri. Lisans alınamadığı için kapsam
bilinçli olarak "ISA + kesme mimarisi doğru" seviyesinde tutuldu.)

---

## 2. Dosya dosya ne var

```
qemuproject/
├── startup.S      Reset kodu (crt0) + kesme giriş noktası (trap_entry)
├── main.c         Hello World + CLINT timer interrupt + trap_handler
├── uart.c/.h      Minimal seri port sürücüsü (NS16550A ve CoreUARTapb)
├── platform.h     ★ Bellek haritası — QEMU/RTG4 anahtarı burada
├── riscv_csr.h    CSR okuma/yazma makroları, mstatus/mie/mcause bitleri
├── linker.ld      Bellek yerleşimi (RAM 0x80000000, stack, bss...)
├── Makefile       Derleme + run + debug hedefleri
├── config.mk      Bu makineye özgü araç yolları (setup.ps1 üretir, git'e girmez)
├── .vscode/
│   ├── tasks.json            Ctrl+Shift+B ile derleme, QEMU çalıştırma
│   ├── launch.json           F5 ile QEMU + GDB debug
│   ├── c_cpp_properties.json IntelliSense'e cross-compiler'ı tanıtır
│   ├── settings.json         Makefile'da tab zorunluluğu vb.
│   └── extensions.json       Önerilen eklentiler
└── tools/
    ├── setup.ps1        Sıfırdan ortam kurulumu (QEMU + toolchain + PATH)
    ├── qemu-debug.ps1   QEMU'yu durdurulmuş + gdbserver açık başlatır
    ├── qemu-stop.ps1    Arkada kalan QEMU'ları kapatır
    ├── smoke.gdb        Debug zincirini doğrulayan GDB betiği
    └── smoke-test.ps1   ★ Uçtan uca otomatik doğrulama (10 kontrol)
```

---

## 3. Kurulum

Kurulu araçlar (bu makinede hazır):

| Araç | Sürüm | Yer |
|---|---|---|
| `riscv-none-elf-gcc` | 15.2.0 | `%APPDATA%/xPacks/...` (xPack GNU RISC-V Embedded GCC) |
| `riscv-none-elf-gdb` | 16.3 | aynı dizin |
| `qemu-system-riscv32` | 11.1.0 | `C:/Program Files/qemu` |
| `mingw32-make` | — | `C:/mingw64/bin` |

Yeni bir makinede tek komut:

```powershell
powershell -ExecutionPolicy Bypass -File tools/setup.ps1
```

Bu betik QEMU'yu winget ile, derleyiciyi xpm ile kurar, `config.mk` üretir ve
yolları kullanıcı PATH'ine ekler. Yönetici yetkisi gerekmez.

> `config.mk` git'e **commit edilmez** — her geliştiricinin kurulum yolu farklıdır.
> Makefile araçları önce `config.mk`'dan, yoksa PATH'ten bulur.

---

## 4. Kullanım

### VSCode'dan

**İlk açılış (bir kez):**

1. VSCode'da `Dosya → Klasör Aç` ile **`qemuproject` klasörünün kendisini** açın
   (tek bir dosyayı değil — `.vscode/` ayarları ancak klasör açılınca devreye girer).
2. Sağ altta "önerilen eklentiler" uyarısı çıkarsa **C/C++** (`ms-vscode.cpptools`)
   eklentisini kurun. Tek zorunlu eklenti bu.
3. Araçlar bulunamıyor hatası alırsanız VSCode'u tamamen kapatıp yeniden açın
   (PATH yeni eklendi, eski pencere görmez) — bkz. §9.

**Günlük kullanım:**

| Ne istiyorsun | Nasıl |
|---|---|
| Derle | `Ctrl+Shift+B` |
| QEMU'da çalıştır | `Ctrl+Shift+P` → `Tasks: Run Task` → `run (QEMU)` |
| Debug (breakpoint, step) | `F5` |
| Hangi debug modu | Sol menü → **Run and Debug** (`Ctrl+Shift+D`) → üstteki listeden seç |
| RTG4 adresleriyle derleme kontrolü | `Tasks: Run Task` → `build (RTG4 hedefi)` |
| Sıfırdan derle | `Tasks: Run Task` → `rebuild` |
| Her şeyi doğrula | `Tasks: Run Task` → `smoke test` |

`run (QEMU)` UART çıktısını VSCode'un terminal panelinde gösterir. Çıkmak için
terminale tıklayıp `Ctrl+A` sonra `X`; ya da terminal panelindeki çöp kutusu simgesi.

> `build (RTG4 hedefi)` gerçek RTG4 adresleriyle (`0x4400_0000` CLINT vb.) derler;
> çıkan `firmware.elf` QEMU'da **çalışmaz**, sadece "RTG4 için de derleniyor mu"
> kontrolüdür. Sonra `F5` veya `Ctrl+Shift+B` yaptığınızda Makefile platform
> değişimini fark edip otomatik olarak QEMU hedefine geri derler.

**Debug sırasında işe yarayanlar:**

- **Breakpoint:** satır numarasının soluna tıklayın. `startup.S` (assembly)
  satırlarına da koyabilirsiniz (`settings.json` bunu açıyor).
- **Adımlama:** `F10` satır atla, `F11` fonksiyonun içine gir, `Shift+F11` çık,
  `F5` devam.
- **Değişken izleme:** sol paneldeki **Watch**'a `g_tick_count` ekleyin.
  CSR'ları da izleyebilirsiniz: `$mcause`, `$mepc`, `$mstatus` (onluk gösterir:
  `-2147483641` = `0x80000007`).
- **GDB komutu çalıştırma:** alttaki **Debug Console**'a `-exec` önekiyle yazın:
  ```
  -exec p/x $mcause            # mcause'u hex göster
  -exec info registers mtvec
  -exec x/2xw 0x0200bff8       # CLINT mtime'i bellekten oku
  ```
- **UART çıktısı** debug sırasında alttaki **Terminal** panelinde,
  `qemu: debug sunucusunu baslat` sekmesinde görünür.
- Debug Console'daki `Warning: Debuggee TargetArchitecture not detected, assuming
  x86_64` uyarısı zararsız: C/C++ eklentisinin mimari listesinde RISC-V yok, ama
  gerçek mimariyi GDB bildiği için debug etkilenmez.

`F5`'e bastığında arka planda sırayla şunlar olur:

1. `build` task'ı projeyi derler
2. `qemu-debug.ps1 -Foreground` QEMU'yu `-S` (işlemci durdurulmuş) ve
   `-gdb tcp::1234` ile VSCode'un terminal panelinde başlatır — UART çıktısı orada
   görünür. Bu görev debug boyunca **açık kalır** (arka plan görevi); kapanırsa
   VSCode QEMU'yu da öldürür
3. Betik 1234 portunun gerçekten dinlemeye geçtiğini doğrular
   (bu kontrol olmasa klasik "connection refused" yarışı yaşanır)
4. `riscv-none-elf-gdb` localhost:1234'e bağlanır, `main`'de durur
5. Debug oturumu bitince `qemu-stop.ps1` QEMU'yu kapatır

İki debug konfigürasyonu var:

- **QEMU: Debug (main icinde dur)** — normal kullanım, `main`'de durur
- **QEMU: Debug (startup.S _start'ta dur)** — reset kodunu ilk komuttan
  itibaren adımlamak için; `startup.S`'in ilk satırında (`_start`,
  `0x80000000`) kaynak koduyla durur. (QEMU aslında önce kendi ROM'unda,
  `0x1000`'de başlar; orada kaynak kod olmadığı için o adım atlanıyor.)

### Terminalden

```powershell
mingw32-make            # derle -> firmware.elf + .bin .hex .map .lst
mingw32-make run        # QEMU'da çalıştır (çıkış: Ctrl+A sonra X)
mingw32-make debug      # QEMU'yu durdurulmuş + gdbserver ile başlat
mingw32-make gdb        # başka bir terminalden GDB ile bağlan
mingw32-make clean
mingw32-make info       # kullanılan araç yollarını göster
```

---

## 5. Beklenen çıktı

```
===========================================
 Hello, World!
 RTG4 / Mi-V RV32 firmware - QEMU SiL
===========================================
 Platform   : QEMU riscv32 'virt' (RTG4/Mi-V vekili)
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

Bellek kullanımı: 2 KB kod + 20 KB (heap/stack dahil) = 8 MB RAM'in %0.27'si.

---

## 6. Timer interrupt nasıl çalışıyor

RISC-V'de zamanlayıcı kesmesi **CLINT** (Core-Local Interruptor) üzerinden kurulur.
İki adet 64-bit register önemli:

- **`mtime`** — sürekli artan serbest sayaç (QEMU virt'te 10 MHz)
- **`mtimecmp`** — hedef değer. `mtime >= mtimecmp` olduğu anda donanım kesme üretir.

### Kurulum zinciri

```
startup.S:  csrw mtvec, trap_entry     -> kesme olunca nereye atlanacak
main.c:     mtimecmp = mtime + adım    -> ilk hedefi koy
            csrs mie, (1<<7)           -> MTIE: timer kesmesini aç
            csrs mstatus, (1<<3)       -> MIE: global kesmeleri aç
```

### Kesme anı

```
mtime >= mtimecmp
      │
      ▼
donanım: mepc <- kesilen PC, mcause <- 0x80000007,
         mstatus.MIE -> MPIE'ye taşınır ve 0'lanır (iç içe kesme olmaz)
         PC <- mtvec
      │
      ▼
startup.S trap_entry:  geçici register'ları yığına kaydet
      │
      ▼
main.c trap_handler:   mcause'u oku
                       bit31 = 1 -> kesme, kod 7 -> timer
                       g_tick_count++
                       mtimecmp = mtime + adım    ◄── kritik satır
      │
      ▼
startup.S:             register'ları geri yükle, mret
                       (mret: MPIE -> MIE geri yüklenir, PC <- mepc)
```

### Dikkat edilen üç nokta

**1. Periyodiklik elle kurulur.** RISC-V zamanlayıcısı *one-shot*'tur; kesme
olduğunda kendini yeniden kurmaz. `trap_handler` içindeki
`mtimecmp = mtime + adım` satırı olmasa kesme bir kez olur ve bir daha asla
olmaz (veya `mtime >= mtimecmp` kalıcı olarak doğru kalıp sonsuz kesme üretir).

**2. RV32'de 64-bit register'a erişim.** `mtime` 64 bit, register'ımız 32 bit.
Okuma sırasında alt kelimeyi okurken üst kelime taşabilir, bu yüzden
"üst–alt–üst oku, üst değişmediyse kabul et" döngüsü kullanılıyor.
Yazarken de RISC-V spesifikasyonunun önerdiği sıra uygulanıyor: önce alt
kelimeyi `0xFFFFFFFF` yap (artık yanlışlıkla kesme tetiklenemez), sonra üstü
yaz, en son alt kelimeyi gerçek değere getir.

**3. `volatile` zorunlu.** `g_tick_count` kesme içinde değişiyor. `volatile`
olmasa derleyici "ana döngüde kimse değiştirmiyor" diye değeri register'da
önbellekler ve değişimi hiç görmezdik. Bu, gömülü yazılımda en sık yapılan
hatalardan biri.

### `trap_entry` neden assembly?

Kesme, bir C fonksiyonunun ortasında aniden olur. İki şey C'de yapılamaz:

1. Kesilen kodun geçici register'larını bozmamak için önce onları yığına
   kaydetmek gerekir (`trap_handler` normal bir C fonksiyonu olduğu için
   kalıcı register'ları kendisi korur; `trap_entry` sadece geçici olanları
   kaydeder — 16 register, 64 byte).
2. Normal C fonksiyonu `ret` ile döner. Kesmeden dönmek için `mret` gerekir;
   `mret` aynı zamanda `mstatus.MPIE`'yi `MIE`'ye geri yükler. `ret` ile
   dönseydiniz kesmeler bir daha hiç açılmazdı.

---

## 7. Doğrulama

```powershell
powershell -ExecutionPolicy Bypass -File tools/smoke-test.ps1
```

Üç aşamada 10 kontrol yapar ve çıkış kodu döner (0 = hepsi geçti), yani
doğrudan CI/CD'ye bağlanabilir:

**A — Derleme**
- `firmware.elf` üretiliyor mu

**B — QEMU'da çalışma (UART çıktısı dosyaya alınır ve denetlenir)**
- `Hello, World!` basılıyor mu
- `platform.h` değerleri doğru mu
- İlk timer tick'i geliyor mu
- **Zaman doğruluğu:** 5 saniye çalıştırılıp son tick sayısının 30–50 arasında
  olduğu kontrol edilir. Bu, `MTIME_FREQ_HZ` değerinin doğru olduğunu, yani
  simüle edilen zamanın gerçek zamanla uyuştuğunu gösterir.

**C — GDB zinciri**
- GDB bağlanıp `main`'de breakpoint tutabiliyor mu
- `mtvec == &trap_entry` mi (kesme vektörü gerçekten kurulmuş mu)
- `mcause == 0x80000007` mi (yakalanan şey gerçekten machine timer IRQ mi)
- Debugger değişken yazabiliyor mu
- GDB betiği sonuna kadar koşuyor mu

Son çalıştırmada doğrulanan canlı değerler:

```
mtvec      = 0x8000007c   = &trap_entry        ✓
mcause     = 0x80000007   machine timer IRQ    ✓
mepc       = 0x800003b2   kesilen komut        ✓
mie        = 0x00000080   bit7 MTIE açık       ✓
mstatus    = 0x00001880   MIE=0, MPIE=1        ✓  (trap içinde doğru davranış)
backtrace  : trap_handler ← trap_entry         ✓  (C ve assembly birlikte)
```

---

## 8. Kart geldiğinde: geçiş yol haritası

**Faz 1 — bu ortam (bitti).** ISA + kesme mimarisi doğru SiL ortamı, VSCode'da
derleme ve kaynak seviyesinde debug.

**Faz 2 — `platform.h`'yi gerçek tasarımla doğrula.** RTG4 bloğundaki adresler
Mi-V referans tasarımlarının tipik değerleridir ve kodda açıkça öyle
işaretlenmiştir. Libero SoC'un ürettiği memory map raporundan şunlar
doğrulanacak:

| Sabit | Koddaki varsayım | Nereden doğrulanacak |
|---|---|---|
| `CLINT_BASE` | `0x4400_0000` | MIV_RV32 yapılandırması |
| `UART_BASE` | `0x7000_1000` | Libero'da CoreUARTapb'ın bağlandığı adres |
| `RAM_BASE` | `0x8000_0000` | LSRAM / TCM / DDR yerleşimi |
| `MTIME_FREQ_HZ` | `50_000_000` | Libero'daki `SYS_CLK` |
| `UART_PCLK_HZ` | `50_000_000` | APB saat frekansı |

**Faz 3 — gerçek donanımda çalıştır.** Mi-V için FlashPro + SoftConsole/OpenOCD
ile JTAG üzerinden yükleme ve debug. GDB arayüzü aynı kaldığı için
`launch.json`'da yalnızca `miDebuggerServerAddress` yerine OpenOCD
konfigürasyonu gelir — kaynak kod ve build sistemi değişmez.

**Faz 4 (opsiyonel) — QEMU'ya gerçek Mi-V makine modeli yaz.** Çevre birim
davranışını da simüle etmek istenirse QEMU'ya `miv` makinesi ve CoreUARTapb
cihaz modeli eklenebilir (QEMU kaynağında C ile, `hw/riscv/` altında).
Simics'in sağladığı cihaz-seviyesi doğruluğa yaklaşmanın yolu budur; haftalar
mertebesinde bir iştir ve ancak çevre birim yazılımı kritikse değer.

---

## 9. Sorun giderme

**`mingw32-make: command not found`** — `C:/mingw64/bin` PATH'te değil.
VSCode'u yeniden başlatın veya `tools/setup.ps1` çalıştırın.

**`riscv-none-elf-gcc: command not found`** — `config.mk` yok ya da eski sürüme
işaret ediyor. `powershell -File tools/setup.ps1 -SkipInstall` ile yeniden üretin.

**F5'te "Unable to start debugging"** — C/C++ eklentisi (`ms-vscode.cpptools`)
kurulu mu? `launch.json` içindeki `miDebuggerPath` toolchain sürümünü
(`15.2.0-1.1`) içeriyor; derleyiciyi güncellediyseniz
`powershell -File tools/setup.ps1 -SkipInstall` çalıştırın — sürümü
`launch.json` ve `c_cpp_properties.json` içinde otomatik düzeltir.

**IntelliSense kırmızı dalgalı çizgi gösteriyor ama derleme başarılı** —
sağ alttaki durum çubuğunda konfigürasyonun `QEMU-virt` olduğundan emin olun;
`Ctrl+Shift+P` → `C/C++: Reset IntelliSense Database`.

**F5'te "The preLaunchTask ... terminated with exit code 1"** — derleme hatası
var demektir; **Problems** panelinde (`Ctrl+Shift+M`) hangi satır olduğu görünür.

**"connection refused" / debug bağlanmıyor** — arkada eski bir QEMU 1234
portunu tutuyor olabilir: `powershell -File tools/qemu-stop.ps1`.

**Makefile hatası `missing separator`** — Makefile satırları **sekme (tab)** ile
girintilenmek zorundadır, boşlukla değil. `.vscode/settings.json` bunu zorlar.

**GDB'de `could not convert 'main' from the host encoding (CP1252)`** — xPack
GDB'nin Windows'ta verdiği zararsız bir uyarı; debug'ı etkilemez.

**QEMU'dan çıkamıyorum** — `-nographic` modunda çıkış: `Ctrl+A` sonra `X`.
