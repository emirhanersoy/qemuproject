# CLAUDE.md — RTG4 / Mi-V RV32 QEMU SiL ortamı

> Bu dosya Claude Code tarafından her oturum başında otomatik okunur.
> Amacı: yeni bir oturumun projeyi sıfırdan anlayıp kaldığı yerden devam
> edebilmesi. İnsan/müdür tarafına dönük anlatım `README.md` içinde.
>
> **Son güncelleme:** 2026-10-17 · **Durum:** Faz 1 bitti, VSCode akışı tamamlandı, 10/10 test geçiyor.

---

## 1. Bağlam (kodda görünmeyen kısım)

- Kullanıcı **Emirhan**, gömülü yazılım mühendisliğine **yeni başlamış**,
  adaptasyon/değerlendirme sürecinde. **Türkçe** konuşuyor, Türkçe açıklama bekliyor.
- Görevi müdürü verdi ve **kullanıcı görevi başta tam anlamamıştı** ("gözümde çoğu şey
  canlanmadı"). Bu yüzden kod teslim etmek yetmez: **kavramları da anlat**
  (soft-core nedir, linker script neden gerekli, trap girişi neden assembly olmak
  zorunda). Kullanıcı bu işi müdürüne **savunmak** zorunda, o yüzden bir yaklaşımın
  sınırlarını dürüstçe söyle.
- Teslim tarihi **2026-10-18**; ortam 2026-10-17 gecesi kuruldu ve çalışır halde bitti.
- Müdürün istediği ekstralar: **debug araçları + timer interrupt** → ikisi de yapıldı.

### Kısıt: Simics lisansı alınamadı

Ekip RTG4 için SiL ortamı istiyor; fiziksel kart henüz gelmedi. **Intel Simics
değerlendirildi ama lisans alınamadı**, alternatif olarak QEMU seçildi. Simics'in asıl
getirisi **cihaz modelleriydi**; bu ortam onu sağlamıyor ve bunu saklamıyor.

---

## 2. En kritik teknik çerçeve — bunu yanlış anlatma

**RTG4 bir işlemci değil, FPGA'dir.** Microchip'in radyasyona dayanıklı uzay FPGA'i.
İçinde hazır CPU yok. İşlemci, Libero SoC ile FPGA dokusuna sentezlenen bir RISC-V
**soft-core**: Mi-V (örn. `MIV_RV32`). Yani "RTG-4 RISC-V işlemcisi" = RTG4 içine
yerleştirilmiş Mi-V çekirdeği.

**QEMU'da RTG4 veya Mi-V makine modeli YOK** ve kısa sürede yazılamaz. Bu yüzden hedef
bilinçli olarak `qemu-system-riscv32 -machine virt`.

Bu neden geçerli bir yaklaşım:

| Katman | Mi-V / RTG4 | Bu ortam | Aynı mı |
|---|---|---|---|
| ISA | RV32I + M, A, C | `rv32imac` | **Birebir aynı** |
| Kesme mimarisi | mtvec/mstatus/mie/mcause/mret | aynı CSR'lar | **Birebir aynı** |
| Zamanlayıcı | CLINT mtime/mtimecmp | CLINT mtime/mtimecmp | **Mantık aynı**, adres farklı |
| CLINT adresi | `0x4400_0000` | `0x0200_0000` | Farklı → `platform.h` |
| UART | CoreUARTapb | NS16550A | Farklı → `platform.h` |
| RAM | `0x8000_0000` | `0x8000_0000` | Aynı |

**Merkezî tasarım kararı:** uygulama kodu **asla çıplak adres kullanmaz**. Tüm adresler
`platform.h`'de isimli. Hedef değiştirmek tek bir `-D` tanımı:

```powershell
mingw32-make                              # PLATFORM_QEMU_VIRT (varsayılan)
mingw32-make PLATFORM=PLATFORM_RTG4_MIV   # gerçek RTG4 — derlendiği doğrulandı
```

`main.c`'deki kesme mantığının tek satırı değişmiyor. **Bu kuralı bozma:** yeni bir
çevre birim eklenecekse adresi `platform.h`'ye, sürücüsü ayrı bir `.c` dosyasına.

### Yapabildiği / yapamadığı — kullanıcıya bunu tekrarla

- **Yapabildiği:** uygulama mantığı, kesme/zamanlayıcı mantığı, zaman hesapları,
  durum makineleri, protokol kodu, regresyon testleri.
- **Yapamadığı:** gerçek çevre birim davranışı, FPGA doku gecikmeleri, saat/ısı/
  radyasyon etkileri, cycle-accurate zamanlama.

---

## 3. Mevcut durum: ne bitti

Faz 1 **tamamlandı ve ölçümle doğrulandı** (tahmin değil, gözlenen çıktı):

```
 Hello, World!
 RTG4 / Mi-V RV32 firmware - QEMU SiL
 Platform   : QEMU riscv32 'virt' (RTG4/Mi-V vekili)
 RAM base   : 0x80000000     CLINT base : 0x02000000
 UART base  : 0x10000000     mtime freq : 10000000 Hz     Tick : 100 ms
[tick 10] uptime = 1 s
[tick 20] uptime = 2 s
[tick 30] uptime = 3 s
```

GDB ile canlı doğrulanan değerler:

```
mtvec      = 0x8000007c   == &trap_entry            OK
mcause     = 0x80000007   machine timer IRQ         OK
mepc       = 0x800003b2   kesilen komutun adresi    OK
mie        = 0x00000080   bit7 MTIE açık            OK
mstatus    = 0x00001880   MIE=0, MPIE=1, MPP=11     OK  (trap içinde doğru davranış)
backtrace  : trap_handler <- trap_entry             OK  (C + assembly birlikte)
```

Boyutlar: QEMU hedefi `text 2042 / bss 20492` (heap 4K + stack 16K dahil), RTG4 hedefi
`text 1994`. 8 MB RAM'in %0.27'si.

**`tools/smoke-test.ps1` → 10/10 kontrol geçiyor, çıkış kodu 0.**
Herhangi bir değişiklikten sonra **ilk iş bunu koşturmak.**

### Bilinçli olarak yapılmayanlar

- **`git init` yapılmadı** (kullanıcı istemedi). `.gitignore` hazır: `config.mk`,
  `*.o`, `*.elf/.bin/.hex/.map/.lst`, `qemu-out.txt` dışarıda.
- QEMU'ya gerçek `miv` makine modeli yazılmadı (Faz 4, bkz. §8).
- newlib/`printf` bağlanmadı; `-nostdlib -lgcc` ile kendi `uart_puts` /
  `uart_put_u32` / `uart_put_hex32` fonksiyonları kullanılıyor.

---

## 4. Ortam: tam yollar ve sürümler

Makine başta **tamamen boştu**; her şey bu oturumda kuruldu. Yönetici yetkisi
gerekmedi, hepsi kullanıcı kapsamında.

| Araç | Sürüm | Tam yol |
|---|---|---|
| `riscv-none-elf-gcc` | 15.2.0 | `C:\Users\Emirhan\AppData\Roaming\xPacks\@xpack-dev-tools\riscv-none-elf-gcc\15.2.0-1.1\.content\bin\` |
| `riscv-none-elf-gdb` | 16.3 | aynı dizin |
| `qemu-system-riscv32` | 11.1.0 | `C:\Program Files\qemu\` |
| `mingw32-make` | — | `C:\mingw64\bin\` (zaten vardı) |
| Node/npm, Python 3.10, winget | — | zaten vardı |

Nasıl kuruldu: QEMU → `winget install SoftwareFreedomConservancy.QEMU`; derleyici →
`npm install -g xpm` + `xpm install --global @xpack-dev-tools/riscv-none-elf-gcc@latest`.

Her ikisi de **kullanıcı PATH'ine kalıcı eklendi** (.NET `SetEnvironmentVariable`,
`User` kapsamı — `setx` bilinçli kullanılmadı, PATH'i 1024 karakterde kırpma riski var).

`tools/setup.ps1` bunların tamamını yeni bir makinede tek komutla tekrarlar.

> **PATH uyarısı:** PATH bu oturumda eklendi; **yeni süreçler** görür ama daha önce
> açılmış terminaller/VSCode görmez. Araç bulunamazsa VSCode'u yeniden başlat ya da
> `config.mk`'daki mutlak yolları kullan.

---

## 5. Dosya haritası

```
qemuproject/
├── CLAUDE.md      <- BU DOSYA (Claude Code devir-teslim)
├── aciklama.md    Konuyu hiç bilmeyen biri için anlatım: amaç, neden, araçlar, nasıl
│                  çalışıyor, örnek çıktının satır satır açıklaması, sonraki adımlar.
├── README.md      İnsan/müdür tarafı: 4 fazlı yol haritası, kesme akış diyagramı,
│                  sorun giderme bölümü.
├── startup.S      135 satır. Reset kodu (crt0) + trap_entry
├── main.c         172 satır. Hello World + CLINT timer IRQ + trap_handler
├── uart.c / .h    116 + 19. NS16550A ve CoreUARTapb sürücüleri (derlemede seçilir)
├── platform.h      77 satır. ★ Bellek haritası — QEMU/RTG4 anahtarı burada
├── riscv_csr.h     56 satır. CSR makroları + mstatus/mie/mcause bit tanımları
├── linker.ld      117 satır. RAM 0x80000000, .init en başta, stack/heap/bss
├── Makefile       all / run / debug / gdb / clean / info hedefleri + platform damgası
├── platform.stamp ÜRETİLEN, git'e girmez. Son derlemenin PLATFORM değeri (§6).
├── config.mk      ÜRETİLEN, git'e girmez. Bu makinenin araç yolları.
├── .gitignore
├── .vscode/
│   ├── tasks.json             build, build (RTG4 hedefi), rebuild, clean, run (QEMU), qemu başlat/durdur, smoke test
│   ├── launch.json            2 debug konfigürasyonu (§7)
│   ├── c_cpp_properties.json  IntelliSense: 2 konfigürasyon (QEMU-virt / RTG4-MiV)
│   ├── settings.json          Makefile'da tab zorunlu, .S'e breakpoint izni, .o gizleme
│   └── extensions.json        yalnızca ms-vscode.cpptools (makefile-tools bilinçli çıkarıldı)
└── tools/
    ├── setup.ps1        Sıfırdan kurulum (QEMU + toolchain + config.mk + PATH)
    ├── qemu-debug.ps1   QEMU'yu -S + gdbserver ile başlatır, PORTUN AÇILMASINI BEKLER
    ├── qemu-stop.ps1    Arkada kalan QEMU'ları kapatır
    ├── smoke.gdb        Debug zincirini doğrulayan GDB betiği (8 adım)
    └── smoke-test.ps1   ★ Uçtan uca doğrulama, 10 kontrol, exit code döner
```

---

## 6. Tasarım kararları ve gerekçeleri

Bunları değiştirmeden önce gerekçeyi oku; her biri bir sorunu çözmek için böyle.

- **`startup.S` (büyük `.S`), `startup.s` değil.** Büyük `.S` on-işlemciden geçer, yani
  `#define`/`#include` kullanılabilir. Orijinal şartnamede `startup.s` yazıyordu;
  bilinçli değiştirildi.
- **`trap_entry` assembly, `trap_handler` C.** Kesme bir C fonksiyonunun ortasında
  aniden olur; (1) geçici register'ları yığına kaydetmek ve (2) `ret` değil `mret` ile
  dönmek C'de yapılamaz. `mret` ayrıca `MPIE → MIE` geri yükler; `ret` ile dönülse
  kesmeler bir daha hiç açılmazdı. `trap_entry` yalnızca 16 caller-saved register
  kaydediyor (64 byte); callee-saved olanları `trap_handler` kendi koruyor.
  `__attribute__((interrupt("machine")))` alternatifi de düşünüldü; mekanizma görünür
  kalsın diye açık assembly tercih edildi (kullanıcının öğrenmesi gerekiyor).
- **Periyodiklik elle kurulur.** RISC-V zamanlayıcısı *one-shot*. `trap_handler`
  içindeki `mtimecmp = mtime + adım` satırı **kaldırılırsa** kesme ya bir kez olur ya da
  sonsuz tetiklenir. Bu satır kritik.
- **RV32'de 64-bit `mtime`.** Okuma: "üst–alt–üst oku, üst değişmediyse kabul et".
  Yazma: önce alt kelimeyi `0xFFFFFFFF` yap, sonra üstü yaz, en son altı gerçek değere
  getir (RISC-V privileged spec önerisi — araya yanlış ara değer yazıp istemeden kesme
  tetiklememek için).
- **`volatile` zorunlu.** `g_tick_count` kesme içinde değişiyor; `volatile` olmasa
  derleyici değeri register'da önbellekler ve ana döngü değişimi hiç görmez.
- **Objeler kök dizinde, `build/` yok.** `mkdir`'ın cmd/sh taşınabilirlik sorunundan
  kaçınmak için (§7'deki mingw32-make tuzağı).
- **Platform damgası (`platform.stamp`).** Objeler `PLATFORM`'a bağlı değildi;
  `PLATFORM=PLATFORM_RTG4_MIV` ile derleyince make "Nothing to be done" deyip **QEMU
  ikilisini RTG4 derlemesi gibi bırakıyordu** (2026-10-17'de yakalandı). Makefile artık
  `$(file ...)` ile PLATFORM değerini dosyaya yazıyor; değer değişince dosya yenilenir,
  tüm objeler yeniden derlenir. Recipe'de shell komutu yok (cmd uyumlu). Kural `all`'dan
  önce tanımlı olduğu için `.DEFAULT_GOAL := all` şart — kaldırma.
- **`-O0 -g3 -gdwarf-4`.** Debugger'da satır satır adımlama birebir çalışsın diye.
  Üretim derlemesinde `-O2 -g` yapılır.
- **`linker.ld` içinde `ASSERT`.** Kod+heap+stack RAM'e sığmazsa **derleme anında** hata
  verir; çalışma anında anlaşılmaz çökme yaşanmaz.
- **`.data` kopyalama döngüsü var ama QEMU'da atlanıyor.** `_data_load_start ==
  _data_start` olduğu için `beq` ile kısa devre olur. Gerçek RTG4'te kod eNVM'den
  çalışacağı için bu döngü şart; aynı kod iki durumda da doğru.
- **`-march=rv32imac_zicsr_zifencei`.** GCC 12+ `zicsr`/`zifencei`'yi ayrı istemek
  zorunda; **bu ek olmadan tüm `csrr`/`csrw` komutları derlenmez.** GCC 15 kullanılıyor,
  yani bu zorunlu.

---

## 7. Sert yoldan öğrenilen tuzaklar

Bunların hepsi bu oturumda gerçekten patladı ve çözüldü. Tekrar yaşamayın.

1. **`mingw32-make` `cmd.exe` kullanıyor** çünkü PATH'te `sh.exe` yok (kontrol edildi).
   Makefile recipe'leri cmd ile uyumlu olmak zorunda. `echo.` ve `^(` gibi cmd'ye özgü
   şeyler kullanılmadı ki `sh.exe` sonradan PATH'e girerse de bozulmasın.
   `clean` hedefi `ifeq ($(OS),Windows_NT)` ile `cmd /c del /q /f` seçiyor.
2. **Makefile sekme (tab) ile girintilenmek zorunda.** `.vscode/settings.json` bunu
   `[makefile]` için zorluyor. Boşlukla girintilenirse `missing separator` hatası.
3. **PowerShell 5.1 harici programın stderr'ini `ErrorRecord`'a çeviriyor.**
   `$ErrorActionPreference = 'Stop'` ile birlikte bu, programın exit code 0 dönmesine
   rağmen betiği öldürüyor. `smoke-test.ps1` bu yüzden `'Continue'` kullanıyor ve
   stdout/stderr'i `Start-Process` + dosyaya yönlendirme ile topluyor
   (`Invoke-Tool` fonksiyonu). **Harici komutlarda `2>&1` kullanma.**
4. **`Start-Process -NoNewWindow -Wait` + çıktı yönlendirmesi + uzun ömürlü torun süreç
   = kilitlenme.** `smoke-test.ps1` başta `qemu-debug.ps1`'i ayrı süreç olarak
   çağırıyordu; QEMU açık kaldığı sürece akışlar kapanmadığı için `-Wait` sonsuz
   bekledi (300 s timeout). Çözüm: `.ps1` yardımcılarını **aynı oturumda** `&` ile
   çağır, ayrı süreç olarak değil.
5. **`qemu-debug.ps1` portun açılmasını bekliyor** (TcpClient ile ~15 s'ye kadar).
   Bu kontrol olmasa GDB, QEMU hazır olmadan bağlanmaya çalışıp klasik
   "connection refused" yarışını yaşıyor. **Bu bekleme döngüsünü kaldırma.**
6. **`set charset ASCII` bu GDB derlemesinde YOK** ("Undefined item"). Denendi,
   kaldırıldı.
7. **GDB'nin `could not convert 'main' from the host encoding (CP1252) to UTF-32`
   uyarısı zararsız.** xPack GDB'nin Windows'taki bilinen davranışı; debug'ı
   etkilemiyor. Düzeltmeye çalışmayın, sadece stderr'i betiği düşürmeyecek şekilde
   yakalayın (madde 3).
8. **QEMU yolunda boşluk var** (`C:\Program Files\qemu`). Makefile recipe'lerinde
   `"$(QEMU)"` diye tırnaklı kullanılıyor; tırnağı kaldırma.
9. **`Start-Process -ArgumentList` öğeleri tırnaklamıyor.** İçinde boşluk olan
   argümanlar (`-ex "set architecture ..."`) bölünüp bozuluyor. GDB komutları bu yüzden
   `tools/smoke.gdb` dosyasında, komut satırında değil.
10. **Linker'ın `LOAD segment with RWX permissions` uyarısı** bare-metal'de normal;
    `-Wl,--no-warn-rwx-segments` ile susturuldu.
11. **`launch.json` ve `c_cpp_properties.json` toolchain sürümünü sabit içeriyor**
    (`15.2.0-1.1`). Derleyici güncellenirse `tools/setup.ps1 -SkipInstall` çalıştır:
    4b adımı bu iki dosyadaki sürümü otomatik düzeltiyor. Yoksa F5 "Unable to start
    debugging" verir. (`${env:APPDATA}` kullanılıyor, yani
    kullanıcı adı taşınabilir; sürüm numarası değil.)
12. **Kod dosyalarında Türkçe yorumlar ASCII** (ı/ş/ğ/ç/ö/ü yok) — kodlama sorunlarından
    kaçınmak için bilinçli. `README.md` ve `CLAUDE.md` tam Türkçe (UTF-8). Bu ayrımı koru.
13. **Bash heredoc'ları bu ortamda büyük içerikte güvenilmez** — backslash kaçışları
    bozulabiliyor (`\\\n` → literal `\n` olarak dosyaya yazıldı, LDFLAGS'ı kırdı) ve
    büyük bloklar `unexpected EOF` veriyor. **Büyük/karmaşık dosyalar için Write
    aracını kullan**, heredoc değil.
14. **VSCode, biten bir task'ın terminalini kapatırken o terminalden doğan TÜM
    süreçleri öldürüyor** — `Start-Process` ile ayrı pencerede açılmış QEMU dahil.
    Belirti: F5'te siyah QEMU penceresi açılıp kapanıyor, Debug Console
    `0x00001000 in ?? ()`'da kalıyor. Smoke test VSCode dışında koştuğu için bunu
    yakalamadı. cpptools'un `OpenDebugAD7`'si VSCode dışında DAP ile sürülünce aynı
    ayarlarla sorunsuz çalıştı → sorun eklentide değil task yaşam döngüsündeydi.
    Çözüm: preLaunchTask `isBackground: true` + `qemu-debug.ps1 -Foreground`
    (QEMU bitene kadar bekler). `-Foreground` olmadan çağrı (smoke test) eski
    davranışta kalır. **endsPattern metni ile betikteki "hazir" satırı eşleşmeli.**

### QEMU açılış mekaniği

`-bios none -kernel firmware.elf` ile QEMU ELF'i RAM'e yükler, hart 0 reset
vektöründe (`0x1000`) başlar ve oradan ELF entry point'ine (`0x80000000`) atlar.
GDB bağlanınca `pc = 0x1000` görmek **normaldir**, hata değil.

### VSCode debug akışı (F5)

1. `build` task'ı derler
2. `qemu-debug.ps1 -Foreground` QEMU'yu `-S` + `-gdb tcp::1234` ile **VSCode'un task
   terminalinde** başlatır ve QEMU kapanana kadar dönmez (`isBackground` task,
   `endsPattern` = "hazir, GDB baglanabilir") — UART çıktısı o terminalde. Bkz. tuzak 14
3. Betik 1234 portunun gerçekten dinlediğini doğrular
4. `riscv-none-elf-gdb` bağlanır, `main`'de durur
5. Oturum bitince `postDebugTask` → `qemu-stop.ps1`

İki konfigürasyon: **"QEMU: Debug (main icinde dur)"** (normal kullanım) ve
**"QEMU: Debug (startup.S _start'ta dur)"** — `postRemoteConnectCommands` ile
`tbreak _start` koyar, `startup.S:18`'de (`0x80000000`) kaynakla durur. Eskiden
`stopAtConnect` ile QEMU ROM'unda (`0x1000`, kaynaksız) duruyordu; değiştirildi.

F5 akışı MI modunda (VSCode'un kullandığı `gdb --interpreter=mi`) elle sürülerek
doğrulandı: bağlantı, `main.c:142` breakpoint, `trap_handler`, `mcause`, `_start`'tan
assembly adımlama çalışıyor. Watch panelinde CSR'lar onluk görünür
(`$mcause` = `-2147483641` = `0x80000007`); hex için Debug Console'da `-exec p/x $mcause`.

---

## 8. Sırada ne var

**Faz 1 — bitti.** Bu ortam.

**Faz 2 — `platform.h`'yi gerçek tasarımla doğrula.** `PLATFORM_RTG4_MIV` bloğundaki
adresler **Mi-V referans tasarımlarının tipik değerleri** ve kodda açıkça öyle
işaretli. **Bunları "doğru biliyorum" diye sunma.** Libero SoC'un memory map
raporundan doğrulanacaklar:

| Sabit | Koddaki varsayım | Nereden doğrulanacak |
|---|---|---|
| `CLINT_BASE` | `0x4400_0000` | MIV_RV32 yapılandırması |
| `UART_BASE` | `0x7000_1000` | Libero'da CoreUARTapb'ın bağlandığı adres |
| `RAM_BASE` | `0x8000_0000` | LSRAM / TCM / DDR yerleşimi |
| `MTIME_FREQ_HZ` | `50_000_000` | Libero'daki `SYS_CLK` |
| `UART_PCLK_HZ` | `50_000_000` | APB saat frekansı |

**Faz 3 — gerçek donanımda çalıştır.** FlashPro + SoftConsole/OpenOCD ile JTAG
üzerinden yükleme ve debug. GDB arayüzü aynı kaldığı için `launch.json`'da yalnızca
`miDebuggerServerAddress` yerine OpenOCD konfigürasyonu gelir; kaynak kod ve build
sistemi değişmez.

**Faz 4 (opsiyonel) — QEMU'ya gerçek Mi-V makine modeli.** Çevre birim davranışı da
simüle edilmek istenirse QEMU kaynağında (`hw/riscv/` altında, C ile) `miv` makinesi ve
CoreUARTapb cihaz modeli yazılabilir. Simics'in sağladığı cihaz-seviyesi doğruluğa
yaklaşmanın yolu budur; **haftalar mertebesinde** bir iş ve ancak çevre birim yazılımı
kritikse değer.

### Kullanıcıya önerilebilecek mantıklı sonraki adımlar

Hiçbiri istenmedi; **sormadan yapma**, ama konuşulursa bunlar sırada:

- `git init` + ilk commit (`.gitignore` hazır)
- Harici kesme (PLIC) örneği — QEMU virt PLIC `0x0C00_0000`, Mi-V PLIC `0x4000_0000`
- Yazılım kesmesi (`msip`) ve `ecall` örneği
- Birim test iskeleti: kodu host'ta derleyip `platform.h`'yi mock'layarak test etmek
- `-O2` ile ayrı "release" derleme hedefi
- GitHub Actions / GitLab CI: `smoke-test.ps1` zaten exit code döndürüyor
- `firmware.hex` zaten üretiliyor — Libero/eNVM programlama akışına bağlanabilir

---

## 9. Hızlı başlangıç (yeni oturum için)

```powershell
# Her şey hâlâ çalışıyor mu?
powershell -ExecutionPolicy Bypass -File tools/smoke-test.ps1
# -> "10 / 10 kontrol gecti" + exit 0 beklenir

# Sadece derle ve çalıştır
mingw32-make
mingw32-make run          # çıkış: Ctrl+A sonra X

# Araçlar bulunamıyorsa
powershell -ExecutionPolicy Bypass -File tools/setup.ps1 -SkipInstall
```

Değişiklik yaptıktan sonra **daima** `smoke-test.ps1` koştur ve sonucu dürüstçe
raporla. Geçmiyorsa hangi kontrolün düştüğünü söyle, "çalışıyor" deme.
