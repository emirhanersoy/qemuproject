# CLAUDE.md — RTG4 / Mi-V RV32 QEMU SiL Ortamı

> Claude Code tarafından her oturum başında otomatik okunur. Amacı: yeni bir
> oturumun projeyi hızla anlayıp kaldığı yerden devam edebilmesi.
> Kullanıcıya/ekibe dönük anlatım `README.md` içinde.
>
> **Son güncelleme:** 2026-10-19 · **Durum:** Faz 1 tamamlandı, smoke test 10/10.

---

## 1. Proje özeti

RTG4 FPGA üzerine sentezlenecek Mi-V (MIV_RV32) RISC-V soft-core için QEMU
tabanlı Software-in-the-Loop geliştirme ortamı. Fiziksel kart gelmeden firmware
yazmak, çalıştırmak ve debug etmek amacıyla kurulmuştur.

Dil: kullanıcı Türkçe çalışıyor, açıklamalar Türkçe yazılır. Kod dosyalarındaki
yorumlar ASCII (bkz. §5), Markdown dosyaları tam Türkçe/UTF-8.

---

## 2. Teknik çerçeve

**RTG4 bir işlemci değil, FPGA'dir.** İçinde hazır CPU yok; işlemci Libero SoC
ile FPGA dokusuna sentezlenen bir RISC-V soft-core'dur (MIV_RV32). QEMU'da RTG4
veya Mi-V makine modeli bulunmadığından hedef bilinçli olarak
`qemu-system-riscv32 -machine virt` seçilmiştir.

ISA (`rv32imac`), kesme mimarisi (mtvec/mstatus/mie/mcause/mret) ve CLINT
zamanlayıcı mantığı iki platformda birebir aynıdır; farklı olan yalnızca çevre
birim adresleri ve UART tipidir.

**Merkezî tasarım kararı:** uygulama kodu asla çıplak adres kullanmaz. Tüm
adresler `platform.h`'de isimlidir, hedef değişimi tek bir `-D` tanımıdır:

```powershell
mingw32-make                              # PLATFORM_QEMU_VIRT (varsayilan)
mingw32-make PLATFORM=PLATFORM_RTG4_MIV   # gercek RTG4 hedefi
```

`main.c`'deki kesme mantığının tek satırı değişmez. **Bu kuralı bozma:** yeni
çevre birim eklenecekse adresi `platform.h`'ye (her iki bloğa), sürücüsü ayrı bir
`.c` dosyasına.

Ortamın kapsamı: uygulama mantığı, kesme/zamanlayıcı davranışı, zaman hesapları,
durum makineleri, protokol kodu, regresyon testleri. Kapsam dışı: gerçek çevre
birim davranışı, FPGA doku gecikmeleri, cycle-accurate zamanlama. Bu sınırı
kullanıcıya dürüstçe aktar, kapsam dışını "doğrulandı" gibi sunma.

---

## 3. Mevcut durum

Faz 1 tamamlandı ve ölçümle doğrulandı: UART banner + 100 ms periyotlu CLINT
timer kesmesi çalışıyor; GDB ile `mtvec`, `mcause`, `mepc`, `mie`, `mstatus`
değerleri ve `trap_handler ← trap_entry` backtrace'i doğrulandı.

Boyut: QEMU hedefi `text 2042 / bss 20492` (4 KB heap + 16 KB stack dahil),
RTG4 hedefi `text 1994`.

**`tools/smoke-test.ps1` → 10/10 kontrol, exit code 0.** Herhangi bir
değişiklikten sonra ilk iş bunu koşturmak; geçmezse hangi kontrolün düştüğünü
söyle, "çalışıyor" deme.

Bilinçli yapılmayanlar: newlib/`printf` bağlanmadı (`-nostdlib -lgcc`, kendi
`uart_*` fonksiyonları); QEMU'ya gerçek `miv` makine modeli yazılmadı (Faz 4).

---

## 4. Ortam

| Araç | Sürüm | Yol |
|---|---|---|
| `riscv-none-elf-gcc` / `gdb` | 15.2.0 / 16.3 | `%APPDATA%\xPacks\@xpack-dev-tools\riscv-none-elf-gcc\15.2.0-1.1\.content\bin\` |
| `qemu-system-riscv32` | 11.1.0 | `C:\Program Files\qemu\` |
| `mingw32-make` | — | `C:\mingw64\bin\` |

Araç yolları `config.mk` içinde (üretilen dosya, git'e girmez). `tools/setup.ps1`
tüm kurulumu yeni bir makinede tekrarlar; `-SkipInstall` yalnızca
`config.mk` + PATH + `.vscode` sürüm damgalarını yeniler.

> PATH değişikliğini yalnızca yeni süreçler görür. Araç bulunamazsa VSCode'u
> yeniden başlat ya da `config.mk`'daki mutlak yolları kullan.

---

## 5. Tasarım kararları

Değiştirmeden önce gerekçeyi oku; her biri bir sorunu çözmek için böyle.

- **`startup.S` (büyük `.S`).** Ön-işlemciden geçsin, `#define`/`#include`
  kullanılabilsin diye.
- **`trap_entry` assembly, `trap_handler` C.** Caller-saved register'ları yığına
  kaydetmek ve `ret` değil `mret` ile dönmek C'de yapılamaz. `mret` ayrıca
  `MPIE → MIE` geri yükler; `ret` ile dönülse kesmeler bir daha açılmazdı.
  `__attribute__((interrupt("machine")))` alternatifi de düşünüldü; mekanizma
  görünür kalsın diye açık assembly tercih edildi.
- **Periyodiklik elle kurulur.** RISC-V zamanlayıcısı one-shot. `trap_handler`
  içindeki `timer_schedule_next()` kaldırılırsa kesme ya bir kez olur ya sonsuz
  tetiklenir.
- **RV32'de 64-bit `mtime`.** Okuma: "üst–alt–üst oku, üst değişmediyse kabul
  et". Yazma: alt kelimeyi `0xFFFFFFFF` yap → üstü yaz → altı gerçek değere
  getir (araya yanlış ara değer yazıp istemeden kesme tetiklememek için).
- **`volatile` zorunlu.** Kesme içinde değişen globaller (`g_tick_count`)
  `volatile` olmasa derleyici değeri register'da önbellekler.
- **Objeler kök dizinde, `build/` yok.** `mkdir`'ın cmd/sh taşınabilirlik
  sorunundan kaçınmak için.
- **`platform.stamp`.** Objeler `PLATFORM`'a bağlı değildi; hedef değiştirince
  make "Nothing to be done" deyip QEMU ikilisini RTG4 derlemesi gibi bırakıyordu.
  Makefile artık `$(file ...)` ile PLATFORM değerini dosyaya yazar; değer
  değişince tüm objeler yeniden derlenir. Kural `all`'dan önce tanımlı olduğu için
  `.DEFAULT_GOAL := all` şart — kaldırma.
- **`-O0 -g3 -gdwarf-4`.** Debugger'da satır satır adımlama birebir çalışsın diye.
  Üretim derlemesinde `-O2 -g`.
- **`linker.ld` içinde `ASSERT`.** Kod+heap+stack RAM'e sığmazsa derleme anında
  hata; çalışma anında anlaşılmaz çökme yok.
- **`.data` kopyalama döngüsü var ama QEMU'da atlanır** (`_data_load_start ==
  _data_start` → `beq` kısa devre). Gerçek RTG4'te kod eNVM'den çalışacağı için
  şart; aynı kod iki durumda da doğru.
- **`-march=rv32imac_zicsr_zifencei`.** GCC 12+ `zicsr`/`zifencei`'yi ayrı
  istemek zorunda; bu ek olmadan tüm `csrr`/`csrw` komutları derlenmez.
- **Kod dosyalarında Türkçe yorumlar ASCII** (ı/ş/ğ/ç/ö/ü yok) — kodlama
  sorunlarından kaçınmak için bilinçli. Markdown dosyaları tam Türkçe. Bu ayrımı
  koru.

---

## 6. Ortama özgü tuzaklar

Hepsi gerçekten yaşandı ve çözüldü.

1. **`mingw32-make` `cmd.exe` kullanıyor** (PATH'te `sh.exe` yok). Recipe'ler cmd
   uyumlu olmak zorunda; `clean` hedefi `ifeq ($(OS),Windows_NT)` ile
   `cmd /c del` seçiyor. `echo.` / `^(` gibi cmd'ye özgü sözdizimi bilinçli
   kullanılmadı ki `sh.exe` sonradan PATH'e girerse de bozulmasın.
2. **Makefile sekme (tab) ile girintilenmek zorunda.** `.vscode/settings.json`
   bunu `[makefile]` için zorluyor.
3. **PowerShell 5.1 harici programın stderr'ini `ErrorRecord`'a çeviriyor.**
   `$ErrorActionPreference = 'Stop'` ile birlikte exit code 0 olsa bile betiği
   öldürüyor. `smoke-test.ps1` bu yüzden `'Continue'` kullanıyor ve çıktıyı
   `Start-Process` + dosyaya yönlendirme ile topluyor. **Harici komutlarda `2>&1`
   kullanma.**
4. **`Start-Process -NoNewWindow -Wait` + çıktı yönlendirme + uzun ömürlü torun
   süreç = kilitlenme.** `.ps1` yardımcıları aynı oturumda `&` ile çağrılır, ayrı
   süreç olarak değil.
5. **`qemu-debug.ps1` portun açılmasını bekliyor** (TcpClient, ~15 s'ye kadar).
   Bu kontrol olmasa GDB "connection refused" yarışına giriyor. **Bekleme
   döngüsünü kaldırma.**
6. **`set charset ASCII` bu GDB derlemesinde yok** ("Undefined item").
7. **GDB'nin CP1252 → UTF-32 dönüşüm uyarısı zararsız**; xPack GDB'nin Windows'ta
   bilinen davranışı. Düzeltmeye çalışma, sadece stderr'i betiği düşürmeyecek
   şekilde yakala (madde 3).
8. **QEMU yolunda boşluk var** (`C:\Program Files\qemu`). Makefile'da `"$(QEMU)"`
   tırnaklı — tırnağı kaldırma.
9. **`Start-Process -ArgumentList` öğeleri tırnaklamıyor**; içinde boşluk olan
   argümanlar bölünüyor. GDB komutları bu yüzden `tools/smoke.gdb` dosyasında.
10. **Linker'ın `LOAD segment with RWX permissions` uyarısı** bare-metal'de
    normal; `-Wl,--no-warn-rwx-segments` ile susturuldu.
11. **`launch.json` ve `c_cpp_properties.json` toolchain sürümünü sabit içeriyor**
    (`15.2.0-1.1`). Derleyici güncellenirse `tools/setup.ps1 -SkipInstall`
    adım 4b bu iki dosyadaki sürümü düzeltir. Yoksa F5 "Unable to start
    debugging" verir.
12. **VSCode, biten bir task'ın terminalini kapatırken o terminalden doğan tüm
    süreçleri öldürüyor** — ayrı pencerede açılan QEMU dahil. Belirti: F5'te QEMU
    penceresi açılıp kapanıyor, Debug Console `0x00001000 in ?? ()`'da kalıyor.
    Çözüm: preLaunchTask `isBackground: true` + `qemu-debug.ps1 -Foreground`.
    **`endsPattern` metni betikteki "hazir" satırıyla eşleşmeli.**
13. **`C:\Users\...\Documents` ağacı yazma korumalı** (Defender controlled folder
    access olması muhtemel). Claude Code bu dizine doğrudan yazamıyor; dosya
    değişiklikleri kullanıcı tarafından ya da VSCode üzerinden uygulanmalı.
    2026-10-19'da README/CLAUDE güncellemesinde yaşandı.

**QEMU açılış mekaniği:** `-bios none -kernel firmware.elf` ile QEMU ELF'i RAM'e
yükler, hart 0 reset vektöründe (`0x1000`) başlar ve ELF entry point'ine
(`0x80000000`) atlar. GDB bağlanınca `pc = 0x1000` görmek normaldir.

**VSCode F5 akışı:** `build` → `qemu-debug.ps1 -Foreground` (QEMU `-S` +
`-gdb tcp::1234`, VSCode task terminalinde, UART çıktısı orada) → port kontrolü →
GDB bağlanır, `main`'de durur → oturum sonunda `postDebugTask` `qemu-stop.ps1`.
İki konfigürasyon var: `main` içinde dur (normal) ve `startup.S` `_start`'ta dur
(`postRemoteConnectCommands` ile `tbreak _start`). Watch panelinde CSR'lar onluk
görünür; hex için Debug Console'da `-exec p/x $mcause`.

---

## 7. Yol haritası

- **Faz 1 — bitti.** Bu ortam.
- **Faz 2 — `platform.h`'yi gerçek tasarımla doğrula.** `PLATFORM_RTG4_MIV`
  bloğundaki `CLINT_BASE` (`0x4400_0000`), `UART_BASE` (`0x7000_1000`),
  `MTIME_FREQ_HZ` / `UART_PCLK_HZ` (`50 MHz`) değerleri Mi-V referans
  tasarımlarının tipik değerleridir ve kodda öyle işaretlidir. **"Doğru biliyorum"
  diye sunma**; Libero SoC'un memory map raporundan ve `SYS_CLK` ayarından
  doğrulanacak.
- **Faz 3 — gerçek donanım.** FlashPro + SoftConsole/OpenOCD ile JTAG üzerinden
  yükleme/debug. GDB arayüzü aynı kaldığı için `launch.json`'da yalnızca
  `miDebuggerServerAddress` yerine OpenOCD konfigürasyonu gelir.
- **Faz 4 (opsiyonel) — QEMU'ya gerçek Mi-V makine modeli.** QEMU kaynağında
  (`hw/riscv/`) `miv` makinesi + CoreUARTapb cihaz modeli. Haftalar mertebesinde
  bir iş; ancak çevre birim yazılımı kritikse değer.

### Önerilebilecek sonraki adımlar (sormadan yapma)

- Harici kesme (PLIC) örneği — QEMU virt `0x0C00_0000`, Mi-V `0x4000_0000`
- Yazılım kesmesi (`msip`) ve `ecall` örneği
- Birim test iskeleti: `platform.h` mock'layıp kodu host'ta derlemek
- `-O2` ile ayrı "release" derleme hedefi
- CI: `smoke-test.ps1` zaten exit code döndürüyor
- `firmware.hex` zaten üretiliyor — Libero/eNVM programlama akışına bağlanabilir

---

## 8. Hızlı başlangıç

```powershell
powershell -ExecutionPolicy Bypass -File tools/smoke-test.ps1   # 10/10 + exit 0 beklenir
mingw32-make
mingw32-make run          # cikis: Ctrl+A sonra X
```

Araçlar bulunamıyorsa: `powershell -ExecutionPolicy Bypass -File tools/setup.ps1 -SkipInstall`
