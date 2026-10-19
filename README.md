# RTG4 / Mi-V RV32 — QEMU Tabanlı SiL Ortamı

RTG4 FPGA üzerine sentezlenecek **Mi-V (MIV_RV32) RISC-V soft-core** için yazılım
geliştirme ve doğrulama ortamı. Fiziksel kart gelmeden önce firmware yazmak,
çalıştırmak ve debug etmek için `qemu-system-riscv32` kullanılır.

İçerik: bare-metal RV32 firmware (reset kodu, linker script, UART sürücüsü, CLINT
timer kesmesi), tek komutla kurulum, VSCode build/debug entegrasyonu ve uçtan uca
regresyon testi.

---

## 1. Ortam neden QEMU `virt`?

RTG4 bir işlemci değil, **FPGA**'dir; içindeki CPU Libero SoC ile FPGA dokusuna
sentezlenen bir soft-core'dur. QEMU'da RTG4/Mi-V makine modeli bulunmadığı için
hedef olarak genel RISC-V platformu `-machine virt` kullanılır.

| Katman | Mi-V / RTG4 | Bu ortam | Durum |
|---|---|---|---|
| ISA | RV32I + M, A, C | `rv32imac` | Aynı |
| Kesme mimarisi | mtvec / mstatus / mie / mcause / mret | aynı CSR'lar | Aynı |
| Zamanlayıcı | CLINT mtime / mtimecmp | CLINT mtime / mtimecmp | Mantık aynı, adres farklı |
| CLINT adresi | `0x4400_0000` | `0x0200_0000` | `platform.h` ile seçilir |
| UART | CoreUARTapb | NS16550A | `platform.h` ile seçilir |
| RAM tabanı | `0x8000_0000` | `0x8000_0000` | Aynı |

**Kapsam:** uygulama mantığı, kesme/zamanlayıcı davranışı, zaman hesapları, durum
makineleri, protokol kodu ve regresyon testleri bu ortamda doğrulanabilir. Gerçek
çevre birim davranışı, FPGA doku gecikmeleri ve cycle-accurate zamanlama
doğrulanamaz; bunlar gerçek kart aşamasına kalır.

---

## 2. Yeni bir Windows makinesinde kurulum

### 2.1 Ön koşullar

| Gerekli | Not |
|---|---|
| Windows 10/11 | Yönetici yetkisi gerekmez, her şey kullanıcı kapsamında kurulur |
| `winget` | Windows 11'de hazır; Windows 10'da "App Installer" ile gelir |
| Node.js + npm | <https://nodejs.org> — yalnızca derleyiciyi indiren `xpm` için gerekli |
| `mingw32-make` | MinGW-w64 ile gelir. Yoksa: `winget install BrechtSanders.WinLibs.POSIX.UCRT` |

### 2.2 Tek komutla kurulum

```powershell
git clone <repo-url> qemuproject
cd qemuproject
powershell -ExecutionPolicy Bypass -File tools\setup.ps1
```

Betiğin yaptıkları:

1. QEMU kurar (`winget install SoftwareFreedomConservancy.QEMU`)
2. `xpm` paket yöneticisini kurar (npm üzerinden)
3. RISC-V çapraz derleyiciyi kurar (`@xpack-dev-tools/riscv-none-elf-gcc`; GCC + GDB, ~500 MB)
4. `config.mk` üretir — bu makinedeki araçların mutlak yolları (git'e girmez)
5. Araç yollarını kullanıcı PATH'ine kalıcı ekler
6. `.vscode/launch.json` ve `c_cpp_properties.json` içindeki toolchain sürümünü günceller

> **Önemli:** PATH değişikliğini yalnızca **yeni açılan** süreçler görür.
> Kurulumdan sonra terminali ve VSCode'u yeniden başlatın.

Araçlar zaten kuruluysa yalnızca yapılandırmayı yenilemek için:

```powershell
powershell -ExecutionPolicy Bypass -File tools\setup.ps1 -SkipInstall
```

### 2.3 Kurulumu doğrulama

```powershell
powershell -ExecutionPolicy Bypass -File tools\smoke-test.ps1
```

Beklenen sonuç: `10 / 10 kontrol gecti` ve çıkış kodu `0`. Betik derlemeyi, QEMU
çalışmasını, UART çıktısını, timer kesmesinin zamanlamasını ve GDB debug zincirini
uçtan uca kontrol eder; exit code döndürdüğü için CI'a doğrudan bağlanabilir.

---

## 3. Günlük kullanım

### Komut satırı

```powershell
mingw32-make                              # derle -> firmware.elf/.bin/.hex/.map/.lst
mingw32-make run                          # QEMU'da calistir (cikis: Ctrl+A sonra X)
mingw32-make debug                        # QEMU'yu durdurulmus baslat + gdbserver :1234
mingw32-make gdb                          # ayri terminalden GDB ile baglan
mingw32-make clean
mingw32-make info                         # aktif platform ve arac yollari
mingw32-make PLATFORM=PLATFORM_RTG4_MIV   # gercek RTG4 hedefi icin derle
```

### VSCode

- **Ctrl+Shift+B** → `build`
- **Terminal → Run Task** → `run (QEMU)`, `build (RTG4 hedefi)`, `rebuild`, `clean`,
  `smoke test (ucdan uca dogrulama)`
- **F5** → QEMU'yu gdbserver ile başlatır, GDB bağlanır ve `main` içinde durur.
  İkinci konfigürasyon `startup.S` içindeki `_start`'ta durur (reset kodunu
  adımlamak için). Oturum bitince QEMU otomatik kapatılır.

Debug'da breakpoint, satır satır adımlama, değişken izleme ve CSR okuma
(Debug Console: `-exec p/x $mcause`) çalışır; `.S` dosyalarına da breakpoint konabilir.

### Beklenen çıktı

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

[tick 10] uptime =  1 s
[tick 20] uptime =  2 s
```

---

## 4. Kendi C kodunu çalıştırmak

### 4.1 Mevcut `main.c`'yi değiştirmek

En hızlı yol: `main()` içindeki döngüyü kendi kodunla değiştirip `mingw32-make run`.
Kullanılabilir hazır fonksiyonlar (`uart.h`):

```c
void uart_init(void);
void uart_putc(char c);
void uart_puts(const char *s);      /* satir sonu eklemez */
void uart_put_u32(uint32_t v);      /* ondalik */
void uart_put_hex32(uint32_t v);    /* 0x???????? */
```

`printf` **yok**: C kütüphanesi (newlib) bilinçli olarak bağlanmadı
(`-nostdlib -lgcc`). Bare-metal'de `printf` hem büyüktür hem de altında işletim
sistemi çağrıları bekler.

Örnek:

```c
#include "platform.h"
#include "uart.h"

int main(void)
{
    uart_init();
    uart_puts("Kendi kodum calisiyor\n");

    for (uint32_t i = 0; i < 5; i++) {
        uart_puts("i = ");
        uart_put_u32(i);
        uart_puts("\n");
    }

    for (;;) {
        __asm__ volatile ("wfi");
    }
}
```

> `main()` **asla dönmemeli**. Bare-metal'de dönülecek bir işletim sistemi yok;
> sonsuz döngü ile bitir.

### 4.2 Yeni bir `.c` dosyası eklemek

1. Dosyayı proje köküne ekle, örn. `sensor.c` + `sensor.h`
2. `Makefile` içindeki obje listesine ekle:

   ```make
   OBJS := startup.o main.o uart.o sensor.o
   ```

3. Başlık dosyası da eklediysen bağımlılık listesine ekle (değiştiğinde yeniden
   derlenmesi için):

   ```make
   HDRS := platform.h riscv_csr.h uart.h sensor.h
   ```

4. `mingw32-make`

### 4.3 Uyulması gereken kural

Bu ortamın tek mimari kuralı: **uygulama kodu çıplak donanım adresi kullanmaz.**
Tüm adresler `platform.h` içinde isimlendirilir. Aynı kaynak kodun hem QEMU hem
RTG4 için derlenebilmesini sağlayan şey budur.

Yeni bir çevre birim eklerken:

- Adres ve sabitleri `platform.h`'nin **her iki** platform bloğuna ekle
- Sürücüyü ayrı bir `.c` dosyasına yaz, `main.c`'ye gömme
- Register erişiminde `MMIO32(...)` / `MMIO8(...)` makrolarını kullan (`volatile`
  içerirler; olmazsa derleyici erişimi optimize edip atabilir)
- Kesme içinde değişen global değişkenleri `volatile` yap

### 4.4 Bellek yerleşimi ve boyut sınırı

Yerleşim `linker.ld` içinde tanımlı: RAM tabanı `0x8000_0000`, `.init` en başta,
ardından `.text`, `.rodata`, `.data`, `.bss`, heap ve stack. Dosyadaki `ASSERT`
ifadesi kod + heap + stack RAM'e sığmazsa **derleme anında** hata verir, çalışma
anında anlaşılmaz bir çökme yaşanmaz. Heap/stack boyutlarını değiştirmek için
`linker.ld` içindeki ilgili sabitleri düzenle.

### 4.5 Kesme eklemek

Timer kesmesi `main.c` içinde örneklenmiş durumda. Yeni bir kesme kaynağı için
`trap_handler()` içindeki `switch (code)` bloğuna `case` ekle. Dikkat edilecek
noktalar:

- `trap_entry` (assembly, `startup.S`) register'ları saklayıp `trap_handler`'a
  atlar ve `mret` ile döner. `mret`, `MPIE → MIE` geri yüklemesini yapar; normal
  `ret` ile dönülse kesmeler bir daha açılmaz.
- RISC-V timer'ı **one-shot**'tır. `trap_handler` içindeki `timer_schedule_next()`
  çağrısı periyodikliği sağlar; kaldırılırsa kesme ya bir kez olur ya da sürekli
  tetiklenir.
- Kesme periyodu `main.c` içindeki `TICK_HZ` ile ayarlanır; `MTIME_STEP` değeri
  `platform.h`'deki `MTIME_FREQ_HZ`'den otomatik hesaplanır, böylece periyot iki
  platformda da aynı kalır.
- Beklenmeyen bir exception oluşursa `trap_handler` `mcause`, `mepc` ve `mtval`
  değerlerini UART'a basıp sistemi durdurur — hata avında ilk bakılacak yer burası.

### 4.6 Her değişiklikten sonra

```powershell
powershell -ExecutionPolicy Bypass -File tools\smoke-test.ps1
```

---

## 5. Dosya yapısı

```
qemuproject/
├── startup.S       Reset kodu (bss temizle, data kopyala, stack kur) + trap_entry
├── main.c          Uygulama: banner + CLINT timer kesmesi + trap_handler
├── uart.c / .h     UART surucusu (NS16550A ve CoreUARTapb, derlemede secilir)
├── platform.h      Bellek haritasi -- QEMU / RTG4 anahtari burada
├── riscv_csr.h     CSR erisim makrolari + mstatus/mie/mcause bit tanimlari
├── linker.ld       Bellek yerlesimi ve boyut kontrolleri (ASSERT)
├── Makefile        all / run / debug / gdb / clean / info
├── config.mk       URETILEN -- bu makinenin arac yollari (git'e girmez)
├── platform.stamp  URETILEN -- son derlemenin PLATFORM degeri
├── .vscode/        tasks, launch, IntelliSense konfigurasyonlari
└── tools/
    ├── setup.ps1       Sifirdan kurulum
    ├── qemu-debug.ps1  QEMU'yu gdbserver ile baslatir
    ├── qemu-stop.ps1   Arkada kalan QEMU'lari kapatir
    ├── smoke.gdb       Debug zincirini dogrulayan GDB betigi
    └── smoke-test.ps1  Uctan uca dogrulama (10 kontrol, exit code doner)
```

---

## 6. Sorun giderme

| Belirti | Çözüm |
|---|---|
| `riscv-none-elf-gcc` bulunamıyor | PATH henüz görünmüyor — terminali/VSCode'u yeniden başlat ya da `tools\setup.ps1 -SkipInstall` çalıştır |
| `mingw32-make` bulunamıyor | MinGW-w64 kurulu değil veya PATH'te değil |
| `missing separator` (Makefile) | Recipe satırları **tab** ile girintilenmeli, boşlukla değil |
| QEMU'dan çıkılamıyor | `Ctrl+A` ardından `X` |
| F5'te "Unable to start debugging" | Derleyici sürümü değişmiş — `tools\setup.ps1 -SkipInstall` yolları düzeltir |
| Port 1234 meşgul | `powershell -File tools\qemu-stop.ps1` |
| `PLATFORM` değiştirildi ama çıktı değişmedi | `platform.stamp` bunu yakalar; şüpheliyse `mingw32-make clean all` |
| GDB'de CP1252 kodlama uyarısı | xPack GDB'nin Windows'ta bilinen zararsız uyarısı, debug'ı etkilemez |
| GDB bağlanınca `pc = 0x1000` | Normal. QEMU reset vektöründen ELF entry point'ine (`0x8000_0000`) atlar |

---

## 7. Yol haritası

| Faz | İçerik | Durum |
|---|---|---|
| 1 | QEMU SiL ortamı: build, çalıştırma, debug, timer kesmesi, regresyon testi | **Tamamlandı** |
| 2 | `platform.h`'deki RTG4 adreslerini Libero SoC memory map raporuyla doğrulama | Kart/bitstream bekliyor |
| 3 | Gerçek donanımda çalıştırma (FlashPro + OpenOCD/SoftConsole üzerinden JTAG) | Kart bekliyor |
| 4 | *(Opsiyonel)* QEMU'ya `miv` makine modeli + CoreUARTapb cihaz modeli | Çevre birim yazılımı kritikse |

**Faz 2 notu:** `platform.h` içindeki `PLATFORM_RTG4_MIV` bloğundaki adresler
(`CLINT_BASE`, `UART_BASE`, `MTIME_FREQ_HZ`, `UART_PCLK_HZ`) Mi-V referans
tasarımlarının tipik değerleridir ve kodda böyle işaretlenmiştir. RTG4 bir FPGA
olduğu için bu adresler Libero SoC tasarımına göre değişir; kart geldiğinde
Libero'nun memory map raporundan doğrulanmalıdır. RTG4 hedefi bugün sorunsuz
derleniyor, ancak adres doğrulaması henüz yapılmamıştır.

**Faz 3 notu:** GDB arayüzü aynı kaldığı için geçişte yalnızca `launch.json`
içindeki `miDebuggerServerAddress` yerine OpenOCD konfigürasyonu gelir; kaynak kod
ve build sistemi değişmez.
