# video.md — Baştan sona okunacak video senaryosu

> **Bu dosyayı açıp yukarıdan aşağıya oku, video biter.**
>
> İşaretler:
> - 🎙️ **SÖYLE** → kutunun içindekini oku (aynen okuyabilirsin)
> - ⌨️ **YAZ** → terminale/konsola yazacağın komut
> - 👁️ **GÖSTER** → ekranda neyi işaret edeceğin
> - 💡 **NOT** → sana bilgi, **söylemene gerek yok**
>
> **Toplam süre:** ~26 dk
> **Kısa versiyon (~10 dk):** Sahne 1, 2, 3, 5.3, 6, 7, 7.5, 8.5, 9.2, 9.3, 10, 12
>
> **İçindekiler:** 1 problem · 2 neden `virt` · 3 araçlar · 3.5 QEMU ne yapar/yapmaz ·
> 4 VSCode · 5 dosyalar (5.1 `startup.S` · 5.2 `linker.ld` · 5.3 `platform.h` ·
> 5.4 `riscv_csr.h` · 5.5 `uart.c/h` · 5.6 `Makefile` · 5.7 `tools/`) ·
> **6 DEMO derleme** · **7 DEMO çalıştırma** · 7.5 `main.c` kurgusu ·
> 8 kesme teorisi · **9 DEMO debug (4 senaryo)** · **10 DEMO kritik satırı bozma** ·
> 11 smoke test · 12 kapanış · EK A-F

---

# ⚠️ ÇEKİMDEN ÖNCE — 2 dakika

⌨️ **YAZ:**
```powershell
copy main.c main.c.yedek
mingw32-make clean
```

💡 **NOT:** Git yok. Sahne 10'da kodu bilerek bozacaksın, yedek olmadan başlama.
`clean` de şart — ilk derlemeyi sıfırdan göstereceksin.

**Kontrol listesi:**
- [ ] `main.c.yedek` oluştu
- [ ] VSCode açık, proje klasörü açık (`C:\Users\Emirhan\Desktop\qemuproject`)
- [ ] Arkada açık QEMU yok → `powershell -ExecutionPolicy Bypass -File tools\qemu-stop.ps1`
- [ ] Ekranda gereksiz pencere yok
- [ ] Yazı tipi büyütüldü: **Ctrl +** ile 2-3 kademe

---

# SAHNE 1 — Problem ve çözüm (1,5 dk)

👁️ **GÖSTER:** Boş VSCode, proje ağacı solda görünsün.

🎙️ **SÖYLE:**

> Merhaba. Bu videoda RTG-4 için hazırladığım geliştirme ve simülasyon
> ortamını anlatacağım, sonra da baştan sona çalıştırıp göstereceğim.
>
> Önce problem: Ekip RTG-4 üzerinde yazılım geliştirecek, ama **fiziksel kart
> henüz gelmedi.** Kart gelene kadar beklersek haftalar kaybediyoruz. İstenen
> şey şuydu: kart olmadan, sadece bilgisayar üzerinde, RTG-4 için yazılacak
> kodu yazabilmek, derleyebilmek, çalıştırabilmek ve hata ayıklayabilmek.
>
> Bunun için QEMU üzerinde bir simülasyon ortamı kurdum. Şu anda ortam
> çalışıyor; üzerinde basit bir uygulama koşuyor ve debug yapılabiliyor.

💡 **NOT:** Buraya "Simics" lafını **kendiliğinden sokma.** Sorulursa:
*"Önce Intel Simics değerlendirildi, lisans alınamadı, QEMU'ya geçtik."*

---

# SAHNE 2 — Neden QEMU'nun `virt` makinesi (2 dk)

👁️ **GÖSTER:** `platform.h` dosyasını aç, üst kısım görünsün.

🎙️ **SÖYLE:**

> Burada bilinmesi gereken bir ayrıntı var, çünkü ortamın tasarımını bu
> belirledi.
>
> **RTG-4 aslında bir işlemci değil, bir FPGA.** Microchip'in radyasyona
> dayanıklı, uzay uygulamaları için ürettiği bir FPGA. İçinde hazır bir CPU
> yok. İşlemci, FPGA'nın içine **sentezlenerek** yerleştiriliyor; buna
> soft-core deniyor. Microchip bunun hazır tasarımını veriyor, adı **Mi-V** ve
> **RISC-V** komut kümesiyle çalışıyor.
>
> Yani "RTG-4 işlemcisi" dediğimiz şey, RTG-4'ün içine yerleştirilmiş bir
> RISC-V işlemcisi.
>
> Bunun bizim için sonucu şu: QEMU'da RTG-4 diye bir seçenek yok, Mi-V diye
> bir seçenek de yok. **Ama RISC-V var.** QEMU'nun RISC-V için sunduğu genel
> amaçlı makinesi `virt`. Ben de hedef olarak onu seçtim:
> `qemu-system-riscv32 -machine virt`.
>
> Bu geçerli bir yaklaşım, çünkü asıl önemli iki katman **birebir aynı**:

👁️ **GÖSTER:** Bu tabloyu ekranda göster ya da sözlü oku.

| Katman | Gerçek RTG-4 / Mi-V | Bizim ortam | Aynı mı |
|---|---|---|---|
| Komut kümesi (ISA) | RV32I + M, A, C | `rv32imac` | **Birebir aynı** |
| Kesme mimarisi | `mtvec`/`mstatus`/`mie`/`mcause`/`mret` | aynı CSR'lar | **Birebir aynı** |
| Zamanlayıcı mantığı | CLINT `mtime`/`mtimecmp` | CLINT `mtime`/`mtimecmp` | **Mantık aynı** |
| CLINT adresi | `0x44000000` | `0x02000000` | Farklı |
| UART donanımı | CoreUARTapb | NS16550A | Farklı |
| RAM başlangıcı | `0x80000000` | `0x80000000` | Aynı |

🎙️ **SÖYLE:**

> İlk iki satır aynı olduğu için yazdığımız kodun mantığı gerçek çipte de
> aynı şekilde çalışacak. Farklı olan kısım çevre birimlerin adresleri — onu
> da çözdüm, Sahne 5'te göstereceğim.
>
> Dürüst sınır şu: bu ortam **yazılım mantığını** doğrular, **donanım
> davranışını** doğrulamaz. Gerçek seri portun elektriksel davranışını, FPGA
> doku gecikmelerini, sıcaklık veya radyasyon etkilerini simüle etmiyor.
> Gömülü projelerde hataların büyük kısmı birinci grupta olduğu için bu ortam
> bugünden işe yarıyor.

💡 **NOT:** Bu paragrafı **atlama.** Müdürün en çok güven duyacağı yer, kendi
sınırını söylediğin yer. Ayrıca "gerçek kartta test ettim" **asla deme** —
gerçek kartta hiç denenmedi, sadece derlendi.

---

# SAHNE 3 — Derleyici: cross compiler (1,5 dk)

👁️ **GÖSTER:** Terminal aç (**Ctrl + `**).

⌨️ **YAZ:**
```powershell
riscv-none-elf-gcc --version
```

🎙️ **SÖYLE:**

> Derleyici olarak **`riscv-none-elf-gcc`** kullandım. Bu bir **cross
> compiler** — yani bu bilgisayarda çalışıyor, ama bu bilgisayar için değil,
> **RISC-V için** kod üretiyor.
>
> İsmi parça parça anlamlı:
> **`riscv`** → üreteceği kod RISC-V için.
> **`none`** → altında **işletim sistemi yok**, yani bare-metal.
> **`elf`** → çıktı dosya formatı.
>
> Normal `gcc` burada işimize yaramaz, çünkü o bu bilgisayarın işlemcisi için
> kod üretir ve Windows'un var olduğunu varsayar.
>
> Sürüm 15.2.0. xPack üzerinden, yönetici yetkisi gerekmeden, kullanıcı
> kapsamında kuruldu.

⌨️ **YAZ:**
```powershell
qemu-system-riscv32 --version
```

🎙️ **SÖYLE:**

> QEMU tarafında da sürüm 11.1.0. Kullandığım dört araç şunlar:

| Araç | Ne işe yarar | Benzetme |
|---|---|---|
| `riscv-none-elf-gcc` | C kodunu RISC-V'nin anladığı dile çevirir | **Çevirmen** |
| `qemu-system-riscv32` | RISC-V işlemcisini taklit eder | **Sahne** |
| `riscv-none-elf-gdb` | Kodu durdurup içine bakmayı sağlar | **Röntgen** |
| `mingw32-make` | Derleme komutlarını sırayla çalıştırır | **Şef** |

🎙️ **SÖYLE:**

> Buna bir de VSCode tarafındaki **C/C++ eklentisini** (`ms-vscode.cpptools`)
> eklemek gerekiyor — breakpoint arayüzünü ve IntelliSense'i o sağlıyor.
>
> Hepsi ücretsiz ve açık kaynak, **lisans maliyeti sıfır.** Hepsi bu makinede
> sıfırdan kuruldu ve **yönetici yetkisi gerekmedi**, kullanıcı kapsamında
> kaldı:

| Araç | Nasıl kuruldu |
|---|---|
| QEMU | `winget install SoftwareFreedomConservancy.QEMU` |
| Derleyici + GDB | `npm install -g xpm`, sonra `xpm install --global @xpack-dev-tools/riscv-none-elf-gcc@latest` |
| `mingw32-make` | Makinede zaten vardı (`C:\mingw64\bin`) |
| cpptools | VSCode eklenti mağazası |

🎙️ **SÖYLE:**

> Her ikisi de kullanıcı PATH'ine kalıcı olarak eklendi.
> `tools/setup.ps1` betiği bu kurulumun tamamını yeni bir bilgisayarda **tek
> komutla** tekrarlıyor — yani ortam tek makineye bağımlı değil.

💡 **NOT:** `mingw32-make` **derleyici değil.** Karıştırırsan müdür fark eder.

---

# SAHNE 3.5 — QEMU ile neyi yapabiliyoruz, neyi yapamıyoruz (1,5 dk)

🎙️ **SÖYLE:**

> Bu ortamla **somut olarak** neler yapılabiliyor, onu netleştirmek istiyorum.

## ✅ Bugün yapılabilenler

| Yetenek | Nasıl |
|---|---|
| RISC-V için C kodu derlemek | `riscv-none-elf-gcc`, `mingw32-make` |
| Kodu çalıştırmak ve çıktısını görmek | `mingw32-make run`, UART terminali |
| Satır satır debug, breakpoint | VSCode **F5** |
| Değişkenleri **çalışma anında** değiştirmek | `-exec set var ...` |
| İşlemcinin kontrol register'larını okumak | `-exec p/x $mcause` |
| Donanım register'larına doğrudan bakmak | `-exec x/2xw ...` |
| Kesme ve zamanlayıcı mantığını doğrulamak | Sahne 8-9 |
| Assembly seviyesinde adımlama | `startup.S` satır satır |
| Hata (exception) ayıklamak | `trap_handler`'ın hata dalı |
| Gerçek kart için **aynı kodu derlemek** | `PLATFORM=PLATFORM_RTG4_MIV` |
| Gerçek kart formatında çıktı üretmek | `firmware.hex` |
| Otomatik regresyon testi | `tools/smoke-test.ps1`, exit code döner |
| Belirli komut sayısında deterministik çalıştırma | QEMU `-icount` |
| Kesmeleri komut seviyesinde izlemek | QEMU `-d int` |

## ❌ Bu ortamın yapamadıkları

| Yapamadığı | Neden |
|---|---|
| Gerçek çevre birim davranışı (SPI, GPIO, gerçek UART elektriği) | QEMU'da o cihaz modelleri yok |
| "Bu komut kaç mikrosaniye sürer" | Cycle-accurate değil |
| FPGA doku gecikmeleri, saat alanları | FPGA simüle edilmiyor |
| Sıcaklık, radyasyon, elektriksel etkiler | Fiziksel dünya |
| RTG-4'e özgü hatalar / errata | Makine modeli yok |

🎙️ **SÖYLE:**

> Tek cümleyle: bu ortam **yazılım mantığını** doğrular, **donanım
> davranışını** doğrulamaz.
>
> Gömülü projelerde hataların büyük kısmı birinci gruptadır — yanlış kesme
> kurulumu, yanlış zaman hesabı, bozuk durum makinesi. Bunların hepsi burada
> bulunabilir. O yüzden ortam kart gelmeden de işe yarıyor.

---

# SAHNE 4 — VSCode entegrasyonu (2 dk)

👁️ **GÖSTER:** Soldaki ağaçta `.vscode` klasörünü aç, 5 dosya görünsün.

🎙️ **SÖYLE:**

> İlk iş olarak geliştirme ortamını kurdum, çünkü isteğin özünde "ben
> VSCode'da kodumu yazayım ve çalışsın" vardı. Ekibin ek bir araç öğrenmesini
> istemedim.
>
> `.vscode` klasöründe beş konfigürasyon dosyası var:

| Dosya | Ne sağlıyor |
|---|---|
| `tasks.json` | Derle / çalıştır / temizle / test kısayolları |
| `launch.json` | **F5** ile debug — iki ayrı konfigürasyon |
| `c_cpp_properties.json` | IntelliSense: kod tamamlama ve tanıma gitme |
| `settings.json` | Makefile'da tab zorunluluğu, assembly'ye breakpoint izni |
| `extensions.json` | Gereken eklenti önerisi |

👁️ **GÖSTER:** **Ctrl+Shift+P** → `Tasks: Run Task` yaz, açılan listeyi göster.

🎙️ **SÖYLE:**

> Tanımlı task'lar şunlar: `build`, `build (RTG4 hedefi)`, `rebuild`, `clean`,
> `run (QEMU)`, debug sunucusunu başlat, durdur ve uçtan uca `smoke test`.
>
> Pratikte ekip sadece iki tuş biliyor: **Ctrl+Shift+B** derliyor, **F5**
> debug başlatıyor.

👁️ **GÖSTER:** `main.c`'yi aç, `CLINT_BASE` üzerine **Ctrl + tıkla** →
`platform.h`'ye atlasın. Sonra **Alt + ←** ile geri dön.

🎙️ **SÖYLE:**

> IntelliSense de çalışıyor — bir sabitin üzerine tıklayınca tanımına
> gidiyor. Bunun için derleyicinin tam yolunu ve hedef mimariyi
> `c_cpp_properties.json`'a tanıttım; yoksa VSCode RISC-V'ye özel şeyleri
> tanımıyor ve her satırın altını kırmızı çiziyor.

---

# SAHNE 5 — Dosyalar ve bare-metal (3 dk)

🎙️ **SÖYLE:**

> Şimdi dosyalara geçelim. Burada anahtar kavram **bare-metal** — yani
> altında işletim sistemi olmadan çalışmak.
>
> Normal bir bilgisayarda program yazdığında, Windows senin için bir sürü iş
> yapıyor: programı belleğe yükler, yığın alanı ayırır, global değişkenleri
> hazırlar, donanıma erişimi yönetir. **Bizim ortamda Windows yok.** O yüzden
> bu işleri **biz** yapıyoruz. Dosyaların çoğu tam olarak bunun için var.

## 5.1 `startup.S` — ilk çalışan kod

👁️ **GÖSTER:** `startup.S`'i aç.

🎙️ **SÖYLE:**

> İşlemciye elektrik verildiğinde hiçbir şey hazır değil. C kodu
> çalışamaz — çünkü C'nin çalışabilmesi için yığının kurulmuş olması
> gerekiyor. Tavuk-yumurta durumu. Bu yüzden ilk çalışan kod **assembly**
> olmak zorunda.
>
> `startup.S` yedi adım yapıyor:

| Adım | Ne | Satır |
|---|---|---|
| 1 | Kesmeleri kapat — henüz hazır değiliz | **18** |
| 2 | Global pointer'ı kur | |
| 3 | **Yığını (stack) kur** — C için şart | **31** |
| 4 | `.data` bölümünü ROM'dan RAM'e kopyala | |
| 5 | `.bss`'i sıfırla — global değişkenler sıfır başlasın diye | |
| 6 | **Kesme vektörünü kur** — kesme olunca nereye gidileceğini söyle | **64** |
| 7 | `main()`'i çağır | |

👁️ **GÖSTER:** Satır **18**'i (`csrw mstatus, zero`) göster, sonra satır
**31**'i (`la sp, _stack_top`), sonra satır **64**'ü (`csrw mtvec, t0`).

🎙️ **SÖYLE:**

> Satır 18 projenin **ilk çalışan komutu**, adresi `0x80000000`.
> Satır 31 yığını kuruyor. Satır 64 ise kesme vektörünü kuruyor — kesme
> olduğunda işlemci `trap_entry` adlı fonksiyona atlayacak. Bu satır kesmenin
> temelini oluşturuyor, Sahne 7'de buraya döneceğim.
>
> Dosyanın alt kısmında bir de `trap_entry` var — kesme geldiğinde çalışan
> assembly parçası. Neden assembly: kesme bir C fonksiyonunun **tam
> ortasında** aniden oluyor. İki şey yapılması gerekiyor ki bu C'den
> yapılamıyor: birincisi işlemcinin geçici register'larını yığına kaydetmek,
> ikincisi geri dönerken normal `ret` değil **`mret`** komutunu kullanmak.
> `mret` dönerken kesmeleri **tekrar açıyor**; normal `ret` ile dönülse
> kesmeler bir daha hiç açılmaz ve sistem tek kesmeden sonra susardı.

## 5.2 `linker.ld` — kod hangi adrese gidecek

👁️ **GÖSTER:** `linker.ld`'yi aç, `MEMORY` bloğunu göster.

🎙️ **SÖYLE:**

> Normal bilgisayarda programı nereye yükleyeceğine Windows karar verir, sen
> karışmazsın. Bare-metal'de ise işlemci **belirli bir adresten** komut
> okumaya başlıyor ve kodu tam oraya koymak **senin** işin.
>
> `linker.ld` bu planı veriyor: RAM `0x80000000` adresinden başlıyor, 8
> megabayt. Yığın için 16 kilobayt, heap için 4 kilobayt ayrılmış, ilk
> çalışacak kod bölümü en başa konmuş.
>
> Bir de güvenlik ağı koydum: dosyanın sonunda bir `ASSERT` var. Kod artı
> yığın artı heap RAM'e sığmazsa **derleme anında** hata veriyor. Bu olmasa,
> taşma çalışma anında anlaşılmaz bir çökme olarak karşımıza çıkardı.

## 5.3 `platform.h` — projenin kalbi ⭐

👁️ **GÖSTER:** `platform.h`'yi aç, iki `#if` bloğunu da göster.

🎙️ **SÖYLE:**

> Bu, projenin en önemli tasarım kararı.
>
> Donanıma erişim şöyle çalışıyor: belirli bir **bellek adresine** yazıyorsun,
> karşılığında donanım bir iş yapıyor. Seri porta harf basmak demek, aslında
> seri portun adresine o harfi yazmak demek.
>
> Problem: o adresler QEMU'da ve gerçek RTG-4'te **farklı.**

| Ne | QEMU'da | Gerçek RTG-4'te |
|---|---|---|
| Seri port | `0x10000000` | `0x70001000` |
| Zamanlayıcı | `0x02000000` | `0x44000000` |
| Saat frekansı | 10 MHz | 50 MHz |

🎙️ **SÖYLE:**

> Kolay yol, bu sayıları doğrudan koda yazmaktı. Ama o zaman kart geldiğinde
> bütün dosyalarda bu sayıları tek tek bulup değiştirmek gerekirdi. Birini
> atlarsan program sessizce yanlış adrese yazar ve saatlerce ne olduğunu
> anlamazsın.
>
> Ben şunu yaptım: **kodun hiçbir yerinde çıplak adres yok.** Hepsi bu tek
> dosyada **isim** olarak duruyor. Dosyanın içinde iki set var — biri QEMU
> için, biri gerçek RTG-4 için. Aynı `CLINT_BASE` ismi bir blokta
> `0x02000000`, diğerinde `0x44000000`.
>
> Hangi setin kullanılacağına **derleme anında** karar veriliyor:

⌨️ **YAZ** (çalıştırmadan, sadece göster):
```powershell
mingw32-make                              # QEMU seti
mingw32-make PLATFORM=PLATFORM_RTG4_MIV   # gerçek RTG-4 seti
```

🎙️ **SÖYLE:**

> İki ayrı proje değil, iki ayrı kopya değil. **Tek kaynak kodu**, içinde bir
> anahtar. `main.c`'nin tek satırı değişmiyor.
>
> Şunu da açıkça söylemem gerekiyor: RTG-4 bloğundaki adresler şu anda Mi-V
> referans tasarımlarının **tipik** değerleri ve kodda bunun böyle olduğu
> açıkça yazılı. Kart geldiğinde yapılacak iş kodu yeniden yazmak değil,
> Libero'nun memory map raporundan **beş sayıyı doğrulamak**: RAM adresi,
> zamanlayıcı adresi, seri port adresi ve iki saat frekansı.

💡 **NOT:** Bu "beş sayı" cümlesi senin en güçlü kozun. Hem dürüst, hem
yapılacak işi somut bir talebe çeviriyor. FPGA tarafından **isim vererek** bu
beş sayıyı isteyeceksin.

## 5.4 `riscv_csr.h` — işlemcinin ayar düğmeleri

👁️ **GÖSTER:** `riscv_csr.h`'yi aç.

🎙️ **SÖYLE:**

> RISC-V işlemcisinin, normal bellekten ayrı duran özel register'ları var;
> bunlara **CSR** deniyor — Control and Status Register. İşlemcinin ayar
> düğmeleri gibi düşünün. Kesme sistemi tamamen bunlarla yönetiliyor:

| CSR | Ne işe yarıyor |
|---|---|
| `mstatus` | **Ana şalter** — kesmeler açık mı kapalı mı |
| `mie` | Hangi kesme türleri açık (zamanlayıcı, harici, yazılım) |
| `mtvec` | **Kesme olunca nereye atlanacak** — `startup.S` burayı kuruyor |
| `mcause` | Kesme neden oldu — kesme mi, hata mı, hangisi |
| `mepc` | Kesilen komutun adresi — geri dönülecek yer |
| `mtval` | Hatada suçlu adres |

🎙️ **SÖYLE:**

> Bunlara C'den doğrudan erişilemiyor, özel assembly komutları gerekiyor:
> `csrr` okumak için, `csrw` yazmak için. Bu dosyada o komutları C
> fonksiyonu gibi kullanılabilir hale getiren makrolar var — `csr_read`,
> `csr_write`, `csr_set`, `csr_clear`. Yani `main.c`'de assembly yazmak
> zorunda kalmıyorum, `csr_read(mcause)` yazıyorum.
>
> Bir de bit tanımları var: "kesme açma biti şudur", "zamanlayıcı kesmesinin
> numarası yedidir" gibi. `main.c`'de çıplak sayı görmemenin sebebi bu dosya.

## 5.5 `uart.c` / `uart.h` — ekrana yazan şey

👁️ **GÖSTER:** `uart.c`'yi aç, iki `#if` bloğunu göster.

🎙️ **SÖYLE:**

> "Ekrana yazı yazmak" gömülü sistemde hiç de basit bir iş değil, çünkü ekran
> yok. Olan şey bir **seri port**. Zincir şöyle işliyor:

```
main.c:  uart_puts(" Hello, World!\n")
            |
            v
uart.c:  her harf için uart_putc(c)
            |
            v
         "gönderme register'ı boş mu?" diye BEKLE   <-- satır 39
            |
            v
         UART_BASE adresine o harfi YAZ
            |
            v
  QEMU o adrese yazıldığını görür  -->  terminale harf basar
            |
            v
          EKRAN
```

🎙️ **SÖYLE:**

> Yani ekrana yazan şey bir kütüphane fonksiyonu değil, **belirli bir bellek
> adresine yapılan tek byte'lık yazma işlemi.** Gerçek kartta o adreste UART
> donanımı olacak ve harf kablodan çıkacak. QEMU'da ise o adresi QEMU
> dinliyor ve terminale basıyor. **Kod ikisini ayırt edemiyor** —
> simülasyonun çalışma prensibi tam olarak bu.
>
> Bir ayrıntı: harf yazmadan önce "gönderme register'ı boş mu" diye
> bekliyoruz. Çünkü seri port yavaş; beklemeden yazarsak önceki harfin
> üstüne yazarız ve çıktı bozulur.

👁️ **GÖSTER:** `uart.c`'de iki `uart_putc` tanımını göster (satır 37 ve 67).

🎙️ **SÖYLE:**

> Ve dosyada **iki sürücü** var. QEMU'nun kullandığı donanım NS16550A — PC
> dünyasının klasik seri port çipi. Gerçek RTG-4'te ise Microchip'in
> **CoreUARTapb**'si olacak. İkisinin register düzeni tamamen farklı, o yüzden
> `uart_putc` ve `uart_init` iki kez yazılmış; hangisinin derleneceğini
> `platform.h`'deki anahtar seçiyor.
>
> Ama yukarı seviye fonksiyonlar — `uart_puts`, `uart_put_u32`,
> `uart_put_hex32` — **ortak.** Yani `main.c` hangi donanımın altta olduğunu
> bilmiyor bile.

👁️ **GÖSTER:** `uart.h`'yi aç.

🎙️ **SÖYLE:**

> `uart.h` ise sadece bu beş fonksiyonun listesi — `main.c`'nin "bende böyle
> fonksiyonlar var" diye bilmesi için.
>
> Ve `printf` **kullanmadım.** Gömülü sistemde `printf` lüks: hem ikili
> boyutu çok büyütüyor hem de altında işletim sistemi çağrıları bekliyor,
> ki bizde işletim sistemi yok. Onun yerine sayıyı basamak basamak yazan
> küçük fonksiyonlarımı yazdım — `uart_put_u32` ondalık, `uart_put_hex32`
> onaltılık.

## 5.6 `Makefile` — derlemeyi yöneten dosya

👁️ **GÖSTER:** `Makefile`'ı aç.

🎙️ **SÖYLE:**

> Elle derlemek şöyle görünürdü: her `.c` dosyası için bir uzun gcc komutu,
> sonra hepsini birleştiren bir linker komutu, sonra ikili ve hex dosyalarını
> üreten komutlar. Her değişiklikte bunları doğru sırayla tekrar yazmak
> gerekir.
>
> `Makefile` bu işi devralıyor. Yaptığı üç şey var:
>
> Birincisi **bayrakları tek yerde tutmak** — hedef mimari, optimizasyon
> seviyesi, debug bilgisi, linker script'in yolu. Hepsi dosyanın üstünde.
>
> İkincisi **sadece değişeni derlemek.** `main.c`'ye dokunduysam sadece onu
> derliyor; `uart.c`'yi tekrar derlemiyor. Dosya tarihlerine bakarak karar
> veriyor.
>
> Üçüncüsü **isimli komutlar sunmak.** Tanımlı hedefler:

| Komut | Ne yapar |
|---|---|
| `mingw32-make` | Derler — varsayılan hedef (`all`) |
| `mingw32-make run` | QEMU'da çalıştırır |
| `mingw32-make debug` | QEMU'yu durdurulmuş halde + GDB sunucusuyla başlatır |
| `mingw32-make gdb` | GDB'yi bağlar |
| `mingw32-make clean` | Üretilen tüm dosyaları siler |
| `mingw32-make info` | Derleyici, platform ve boyut özetini basar |
| `mingw32-make help` | Hedeflerin listesini basar |

🎙️ **SÖYLE:**

> Bir de burada çözmek zorunda kaldığım gerçek bir hata var, onu anlatmak
> istiyorum çünkü sessiz hata türüne iyi bir örnek.
>
> Başta derlenmiş dosyalar hedef platforma **bağlı değildi.** QEMU için
> derleyip sonra RTG-4 için derlemek istediğimde `make` "yapacak bir şey yok"
> diyordu — çünkü kaynak dosyalar değişmemişti. Sonuç: elimde QEMU
> adresleriyle derlenmiş bir ikili vardı ama ben onu RTG-4 derlemesi
> sanıyordum. **Hiçbir hata mesajı yoktu.**
>
> Çözüm olarak `platform.stamp` adlı küçük bir dosya ekledim: son derlemenin
> hangi platform için yapıldığını içinde tutuyor. Platform değişince o dosya
> yenileniyor, `make` de bunu görüp **her şeyi baştan derliyor.**

💡 **NOT:** Bu anekdotu anlatmak sana puan kazandırır — sessiz bir hatayı
yakalamış ve kalıcı olarak kapatmış olmak mühendislik olgunluğu göstergesi.

💡 **NOT:** `Makefile` **sekme (tab)** ile girintilenmek zorunda, boşlukla
olmaz. `.vscode/settings.json` bunu zorluyor. Sorulursa söyle, kendiliğinden
girme.

## 5.7 `tools/` klasörü — 5 yardımcı betik

👁️ **GÖSTER:** `tools` klasörünü aç, 5 dosya görünsün.

🎙️ **SÖYLE:**

> Bu klasör kodun parçası değil, **ortamın** parçası. Beş dosya var:

| Dosya | Ne yapıyor |
|---|---|
| **`setup.ps1`** | Sıfırdan kurulum: QEMU + derleyici + PATH + `config.mk`. Yeni bilgisayarda **tek komut** |
| **`qemu-debug.ps1`** | QEMU'yu durdurulmuş halde + GDB sunucusuyla başlatır, **portun açılmasını bekler** |
| **`qemu-stop.ps1`** | Arkada kalan QEMU süreçlerini kapatır |
| **`smoke.gdb`** | 8 adımlı GDB betiği: bağlan, kesme vektörünü doğrula, zamanlayıcıyı oku, değişkeni değiştir |
| **`smoke-test.ps1`** | ⭐ Uçtan uca 10 kontrol, **çıkış kodu döndürür** |

🎙️ **SÖYLE:**

> `qemu-debug.ps1`'de özellikle söylemek istediğim bir ayrıntı var. Betik
> QEMU'yu başlattıktan sonra **1234 portunun gerçekten dinlediğini
> doğruluyor.** Bu kontrol olmasa GDB, QEMU henüz hazır değilken bağlanmaya
> çalışır ve klasik "connection refused" yarış durumu yaşanır — bazen çalışır,
> bazen çalışmaz. En sinir bozucu hata türü. O yüzden bekleme döngüsü var.
>
> `smoke-test.ps1` ise ortamın sigortası. On kontrolü sırayla yapıyor ve
> **çıkış kodu** döndürüyor — yani bir CI sistemine olduğu gibi bağlanabilir.
> Sahne 11'de çalıştıracağım.
>
> Bir de `config.mk` var — `setup.ps1` bunu üretiyor ve **bu makineye özgü**
> araç yollarını tutuyor. Sürüm kontrolüne girmemesi gereken dosya, çünkü her
> bilgisayarda farklı.

---

# SAHNE 6 — DEMO 1: Derleme (2 dk)

👁️ **GÖSTER:** Terminal.

⌨️ **YAZ:**
```powershell
mingw32-make
```

🎙️ **SÖYLE (derlerken):**

> Şimdi derliyorum. Ekranda akan satırlar `riscv-none-elf-gcc` çağrıları.
>
> Dikkat edilecek iki bayrak var. Birincisi
> **`-march=rv32imac_zicsr_zifencei`** — hedef komut kümesi. `rv32i` temel 32
> bit, `m` çarpma-bölme, `a` atomik işlemler, `c` sıkıştırılmış komutlar. Sonundaki
> `zicsr` kritik: GCC 12'den sonra CSR komutlarını ayrıca istemek zorunlu, bu
> ek olmadan kesmelerle ilgili tek satır derlenmiyor.
>
> İkincisi **`-nostdlib -nostartfiles`** — standart kütüphaneyi ve standart
> başlangıç kodunu bağlama demek. Çünkü başlangıç kodunu biz yazdık,
> `startup.S`.

⌨️ **YAZ:**
```powershell
mingw32-make info
```

🎙️ **SÖYLE:**

> Bu komut derlemenin özetini veriyor: kullanılan derleyici, hedef platform ve
> **bölüm boyutları.** Kod 2 kilobayt civarında, veri alanı ise yığın ve heap
> dahil 20 kilobayt. 8 megabayt RAM'in **binde üçü.** Yani uygulama büyümek
> için fazlasıyla yer var.

👁️ **GÖSTER:** Dosya ağacında `firmware.elf`, `firmware.bin`, `firmware.hex`,
`firmware.map`, `firmware.lst` dosyalarını göster.

🎙️ **SÖYLE:**

> Derleme beş çıktı üretiyor. `firmware.elf` debug bilgisi içeren asıl dosya —
> QEMU ve GDB bunu kullanıyor. `firmware.bin` ham ikili. **`firmware.hex`**
> ise gerçek kartı programlarken Libero'nun kullanacağı format — yani bu
> zincir gerçek donanıma kadar hazır. `firmware.map` neyin hangi adrese
> gittiğini, `firmware.lst` ise C kodunun karşılığındaki assembly'yi
> gösteriyor.

## Şimdi gerçek RTG-4 hedefi için derleyelim

⌨️ **YAZ:**
```powershell
mingw32-make PLATFORM=PLATFORM_RTG4_MIV
```

🎙️ **SÖYLE:**

> Aynı kaynak kod, bu kez gerçek RTG-4 hedefi için. Gördüğünüz gibi hatasız
> derleniyor ve ben `main.c`'ye **hiç dokunmadım.** Tek bir parametre
> değiştirdim.
>
> Burada dikkatli olmam gereken bir şey var: bunu **çalıştıramıyorum.** Çünkü
> ne kart var, ne de QEMU'da o adresler mevcut. Yani söylediğim şey "gerçek
> kartta çalıştı" değil; **"gerçek kart hedefi için derlendiğini doğruladım."**

💡 **NOT:** Bu ayrımı kaybetme. Müdürün "yani kart gelince direkt çalışır mı"
sorusuna cevabın: *"Derlenir. Çalışması için o beş adresin doğrulanması
gerekiyor."*

⌨️ **YAZ** (QEMU hedefine geri dön — **bunu atlamayı unutma**):
```powershell
mingw32-make
```

💡 **NOT:** Bu satırı atlarsan Sahne 7'de QEMU hiçbir şey basmaz, çünkü ikili
dosya RTG-4 adresleriyle derlenmiş olur.

---

# SAHNE 7 — DEMO 2: Çalıştırma (1,5 dk)

⌨️ **YAZ:**
```powershell
mingw32-make run
```

👁️ **GÖSTER:** QEMU'nun bastığı banner ve akmaya başlayan tick satırları.

🎙️ **SÖYLE:**

> Ve çalışıyor. Ekranda gördüğünüz çıktı QEMU'nun taklit ettiği RISC-V
> işlemcisinin üzerinde koşan firmware'den geliyor.
>
> "Hello, World!" satırı isteğin karşılığı. Altında firmware'in kendi
> raporladığı değerler var: hedef platform, RAM adresi, zamanlayıcı adresi,
> seri port adresi, zamanlayıcı frekansı ve tick periyodu. Bunları koda
> gömmedim, firmware `platform.h`'den okuyup basıyor — yani ekranda gördüğünüz
> adresler o derlemede **gerçekten kullanılan** adresler.
>
> Altındaki satırlar her saniye bir geliyor:
> `[tick 10] uptime = 1 s`, `[tick 20] uptime = 2 s`...
>
> Buradaki önemli nokta: bu satırlar bir **döngü sayarak** basılmıyor. Her
> biri **on tane gerçek donanım kesmesinin** sonucu. Nasıl çalıştığını şimdi
> anlatacağım.

🎙️ **SÖYLE (çıkmadan önce):**

> QEMU'dan çıkmak için **Ctrl+A**, sonra **X**.

⌨️ **YAZ:** `Ctrl+A` → `X`

---

# SAHNE 7.5 — `main.c` kurgusu: tam olarak ne yapıyoruz (2 dk)

👁️ **GÖSTER:** `main.c`'yi aç, satır **130-163** aralığı (`main` fonksiyonu).

🎙️ **SÖYLE:**

> Demin çalıştırdığımız şeyin kurgusu şu: **her saniye ekrana çalışma süresini
> yazan bir uygulama** — ama bunu döngü sayarak değil, **donanım
> zamanlayıcısının kesmesiyle** yapıyor.
>
> Bu kurguyu bilinçli seçtim. "Hello, World!" tek başına hiçbir şey kanıtlamaz
> — bir satır basıp bitse, kesme sisteminin çalıştığını gösteremezdim. Saniye
> sayan bir uygulama ise şunların **hepsini** aynı anda kanıtlıyor: derleme
> zinciri, başlangıç kodu, yığın kurulumu, UART sürücüsü, zamanlayıcı
> donanımı, kesme vektörü, kesmeden geri dönüş ve C ile assembly'nin birlikte
> doğru çalışması.

## `main` fonksiyonu — 5 adım

```c
int main(void)
{
    uint32_t reported = 0;

    uart_init();          // 1) seri portu hazırla
    print_banner();       // 2) açılış ekranını bas
    timer_start();        // 3) alarmı kur ve kesmeleri AÇ

    while (1) {
        wfi;                            // 4) UYU — kesme gelene kadar
        uint32_t now = g_tick_count;

        if (her tam saniyede) {          // 5) saniye dolduysa rapor bas
            uart_puts("[tick "); ...
        }
    }
}
```

🎙️ **SÖYLE:**

> Adım adım:
>
> **Bir:** `uart_init` seri portu hazırlıyor — baud hızını ve ayarlarını kurup
> yazmaya hazır hale getiriyor.
>
> **İki:** `print_banner` açılış ekranını basıyor. Burada bir ayrıntı var:
> banner'da gördüğünüz adresler ve frekanslar koda gömülü değil, firmware
> `platform.h`'den okuyup basıyor. Yani ekranda gördüğünüz değerler **o
> derlemede gerçekten kullanılan** değerler. Bu, hangi platform için
> derlendiğini çalışma anında doğrulamanın yolu.
>
> **Üç:** `timer_start` zamanlayıcıyı kuruyor ve kesmeleri açıyor. Bu satırdan
> sonra sistem canlı.
>
> **Dört:** Sonsuz döngüde `wfi` komutu — işlemciyi kesme gelene kadar
> **uyutuyor.** Yani ana döngü aslında hiçbir iş yapmıyor.
>
> **Beş:** Uyandığında sayaca bakıyor. Sayaç her kesmede bir artıyor, saniyede
> on kesme var. Yani onda bir uyanışta tam saniye doluyor; o anda ekrana bir
> satır basıyor.

## İki değişken

| Değişken | Ne tutuyor |
|---|---|
| `g_tick_count` | **Kesmenin** artırdığı sayaç — kaç kesme oldu |
| `reported` | Ana döngünün tuttuğu "en son hangi saniyeyi bastım" |

🎙️ **SÖYLE:**

> Bu iki değişkenin ayrı olması önemli. `g_tick_count`'u **kesme** artırıyor,
> `reported`'ı **ana döngü** güncelliyor. İkisini karşılaştırarak aynı
> saniyeyi iki kez basmamayı sağlıyoruz.
>
> Ve iş bölümü şu: **kesme mümkün olduğu kadar kısa.** İçinde sadece iki
> satır var — sayacı artır, alarmı yeniden kur. Ekrana yazma işini kesmenin
> içinde **yapmıyoruz**, ana döngüye bırakıyoruz. Çünkü kesme içinde uzun süre
> kalmak diğer kesmeleri geciktirir; gömülü sistemlerde temel kural bu.

💡 **NOT:** "Neden kesmenin içinde yazdırmıyoruz" sorusu gelirse cevap yukarıda.
Bu, deneyimli birinin soracağı sorudur ve cevabı bilmek iyi görünür.

---

# SAHNE 8 — Kesme nasıl çalışıyor (3 dk)

👁️ **GÖSTER:** `main.c`'yi aç.

## 8.1 Neden kesme — alternatifi ne

🎙️ **SÖYLE:**

> Her saniye ekrana yazı yazmanın iki yolu var.
>
> **Birinci yol, döngü:** sürekli saate bakmak. `while` içinde "saat geldi mi,
> geldi mi, geldi mi" diye sormak. Bu çalışır ama işlemci saniyede milyonlarca
> kez boşa saate bakar. İşlemci yüzde yüz meşgul, hiçbir iş yapmıyor. Gerçek
> donanımda pil tüketir.
>
> **İkinci yol, kesme:** alarmı kur ve uyu. Biz bunu yaptık.

👁️ **GÖSTER:** `main.c` satır **140-148** aralığı, özellikle satır **146**
(`wfi`).

🎙️ **SÖYLE:**

> Ana döngüde `wfi` komutu var — **Wait For Interrupt.** İşlemciyi kesme gelene
> kadar **uyutuyor.** Yani şu anda ana döngü hiçbir iş yapmıyor, uyuyor.
> Donanım onu her yüz milisaniyede uyandırıyor.

## 8.2 Kesme neden "kesme"

🎙️ **SÖYLE:**

> Kesme, programı **ortasından kesiyor.** Sen fonksiyon çağırmıyorsun;
> **donanım** araya giriyor.
>
> Akış şöyle:

```
main() satır 146'da uyuyor
        |
        |  <-- ALARM!  (donanım araya girdi, main'in haberi yok)
        v
   trap_entry   (startup.S)    <-- geçici register'ları yığına kaydet
        v
   trap_handler()  (main.c)    <-- g_tick_count++         satır 86
                               <-- timer_schedule_next()  satır 87
        v
   trap_entry / mret           <-- register'ları geri yükle, kesmeleri aç
        |
        v
main() satır 148'de devam ediyor   <-- hiçbir şey olmamış gibi
```

👁️ **GÖSTER:** **Ctrl+F** ile `main.c` içinde `trap_handler` ara.

🎙️ **SÖYLE:**

> Şunu göstermek istiyorum: `main.c`'de `trap_handler`'ı **çağıran bir satır
> yok.** Arayın, bulamazsınız. Buna rağmen bu fonksiyon saniyede on kez
> çalışıyor. Onu çağıran şey işlemcinin kendisi — `startup.S` satır 64'te
> kurduğumuz kesme vektörü sayesinde.
>
> İşte kesme tam olarak bu: kod akışının dışından gelen bir çağrı.

## 8.3 CLINT — saat ve alarm kolu

🎙️ **SÖYLE:**

> Zamanlayıcı donanımının adı **CLINT** ve iki parçası var.
>
> **`mtime`** — saatin kendisi. Durmadan ileri sayar, durdurulamaz,
> sıfırlanamaz. QEMU'da saniyede on milyon artıyor.
>
> **`mtimecmp`** — alarm kolu. "Saat şu değere gelince beni uyandır."
>
> İkisi de bellekte birer adres, ikisi de `platform.h`'de isimli.

👁️ **GÖSTER:** `main.c`'deki fonksiyonları sırayla göster.

🎙️ **SÖYLE:**

> `main.c`'deki altı yardımcı fonksiyon bu iki şeyi yönetiyor:

| Fonksiyon | Ne yapıyor |
|---|---|
| `mtime_read()` | Saatin şu anki değerini okur → *"Saat kaç?"* |
| `mtimecmp_write(x)` | Alarm kolunu `x` değerine kurar → *"Beni 7'de kaldır"* |
| `timer_schedule_next()` | `mtimecmp = mtime + 100 ms` → *"Beni 100 ms sonra kaldır"* |
| `timer_start()` | İlk alarmı kurar **ve kesmeleri açar** |
| `trap_handler()` | **Alarm çaldığında çalışan fonksiyon** |
| `print_banner()` | Açılış ekranını basar — mantığı yok |

👁️ **GÖSTER:** Satır **30-40** (`mtime_read`).

🎙️ **SÖYLE:**

> `mtime_read` neden dokuz satır, oysa iş "bir sayı oku"? Sebep şu: **saat 64
> bitlik, ama işlemci 32 bitlik.** Sayıyı tek seferde okuyamıyoruz, iki parça
> halinde okuyoruz — üst yarı ve alt yarı.
>
> Problem: iki okuma arasında saat ilerliyor. Dijital saatte önce saati sonra
> dakikayı okumak gibi — `07:59` okurken tam o anda `08:00` olursa `07:00`
> okumuş olursunuz. Bir saat yanlış.
>
> Çözüm: **üst, alt, sonra üstü tekrar oku.** Üst yarı değişmemişse okuma
> güvenli. Değişmişse baştan yap. Bu, RISC-V spesifikasyonunun önerdiği
> yöntem.
>
> `mtimecmp_write` de aynı sebepten üç adımlı: yarısı yazılmış bir alarm değeri
> **yanlışlıkla alarmı hemen çaldırabilir.** O yüzden önce alarmı imkânsız bir
> değere çekip, sonra gerçek değeri yazıyor.

## 8.4 Kesmenin açılması — üç şalter

👁️ **GÖSTER:** Satır **66-71** (`timer_start`).

🎙️ **SÖYLE:**

> Kesmenin gerçekleşmesi için **üç şartın birden** sağlanması gerekiyor:
>
> Birincisi alarm vaktinin gelmesi — `mtime` değeri `mtimecmp`'i geçmeli.
> İkincisi zamanlayıcı kesmesinin açık olması — satır 69.
> Üçüncüsü **genel** kesmelerin açık olması — satır 70.
>
> Üçünden biri kapalıysa hiçbir şey olmaz. `timer_start` tam olarak bu üçünü
> yapıyor ve o andan itibaren sistem canlı.

## 8.5 En kritik satır: 87

👁️ **GÖSTER:** Satır **87** (`timer_schedule_next();`).

🎙️ **SÖYLE:**

> Ve projenin en kritik tek satırı bu.
>
> RISC-V'nin zamanlayıcısı **tek seferlik.** Çaldıktan sonra kendini yeniden
> kurmuyor. Telefonunuzdaki alarmın "her gün tekrarla" seçeneği kapalı gibi:
> çalar, susar, biter.
>
> Periyodikliği **yazılım** sağlamak zorunda. Her kesmede bir sonraki alarmı
> elle kurmak gerekiyor; bunu yapan satır bu.
>
> Bu satır silinirse ne olur? Birazdan **göstereceğim.**

👁️ **GÖSTER:** Satır **18** (`volatile uint32_t g_tick_count`).

🎙️ **SÖYLE:**

> Bir ayrıntı daha: sayaç değişkeni `volatile` ile tanımlı. Bunun sebebi şu —
> bu değişken **kesmenin içinde** değişiyor, ana döngünün bundan haberi yok.
> `volatile` olmasa derleyici "bu döngüde kimse bunu değiştirmiyor" diye
> optimize edip değeri register'da önbelleklerdi ve ana döngü değişimi **hiç
> görmezdi.** Program sessizce yanlış çalışırdı.

---

# SAHNE 9 — DEMO 3: Debug (4 dk)

## 9.1 Debug nasıl kurulu

🎙️ **SÖYLE:**

> Şimdi debug'a geçiyorum. Mimari şöyle çalışıyor:
>
> QEMU'nun içinde bir **GDB sunucusu** var. QEMU'yu durdurulmuş halde
> başlatıyorum, TCP 1234 portunu dinliyor. `riscv-none-elf-gdb` o porta
> bağlanıyor, VSCode da GDB'yi sürüyor. Yani breakpoint koyduğumda VSCode →
> GDB → QEMU zinciri işliyor.
>
> Bunun önemi şu: **gerçek donanımda da mimari aynı.** Kart geldiğinde QEMU'nun
> yerine JTAG üzerinden OpenOCD gelecek, geri kalan her şey aynı kalacak —
> aynı GDB, aynı VSCode, aynı breakpoint'ler. `launch.json`'da tek bir satır
> değişecek.

## 9.2 Senaryo A: "Kesme gerçekten oluyor mu?" ⭐

**Breakpoint:** `main.c` satır **86** (`g_tick_count++;`) — sol kenara tıkla,
kırmızı nokta çıksın.

**F5** → `QEMU: Debug (main icinde dur)` → sonra **F5 tekrar** (devam et).

👁️ **GÖSTER:** Breakpoint'e düştü.

🎙️ **SÖYLE:**

> Kesmenin içindeyiz. Şimdi işlemciye "neden buradayız" diye soruyorum.

⌨️ **YAZ** (DEBUG CONSOLE):
```
-exec p/x $mcause
```

🎙️ **SÖYLE:**

> `0x80000007`. Bunu okumak çok basit:
>
> **Sekiz ile başlıyor** — yani en üst bit bir. Bu "gelen şey bir **kesme**,
> bir hata değil" demek.
> **Son hane yedi** — yani "**zamanlayıcı** kesmesi".
>
> İkisini birleştirince: zamanlayıcıdan gelen bir kesmenin içindeyiz.

⌨️ **YAZ:**
```
-exec p g_tick_count
-exec p/x $mepc
```

🎙️ **SÖYLE:**

> Sayaç ilerliyor. `mepc` ise **kesilen komutun adresi** — yani ana döngüdeki
> `wfi` satırı. Kesme bitince program oraya geri dönecek.

👁️ **GÖSTER:** Soldaki **CALL STACK** panelini işaret et.

🎙️ **SÖYLE:**

> Ve asıl kanıt burada. Call Stack paneline bakın:
>
> `trap_handler`, onun altında `trap_entry`. **`main` yok.**
>
> Normal bir fonksiyon çağrısında `main` listede olurdu. Burada yok, çünkü bu
> fonksiyonu `main` çağırmadı — **donanım** çağırdı. Üstelik hem C hem
> assembly birlikte doğru çözümleniyor; yığın kaydı doğru kurulmuş olmasa bu
> panel bozuk görünürdü.
>
> Kesmenin kanıtı tam olarak bu panel.

## 9.3 Senaryo B: "Bir saniyeyi beklemeden gör" ⭐

🎙️ **SÖYLE:**

> Şimdi bu ortamın neden değerli olduğunu gösteren senaryoya geliyorum.
>
> Ekrana saniyelik satırı basan koda breakpoint koyarsam **on kesme beklemem**
> gerekir, yani onlarca kez devam tuşuna basmak. Gerçek projede bu "saat 24
> olunca ne oluyor" ya da "sayaç taşınca ne oluyor" sorusuna dönüşür ve saatler
> beklemek gerekir.
>
> Debugger'da beklemiyoruz. Değişkeni **dışarıdan** değiştiriyorum.

**Breakpoint'i kaldır** (satır 86), **yeni breakpoint:** satır **148**
(`uint32_t now = g_tick_count;`). **F5** ile oraya düş.

⌨️ **YAZ:**
```
-exec p g_tick_count
-exec set var g_tick_count = 9
-exec p g_tick_count
```

🎙️ **SÖYLE:**

> Sayacı dokuza çektim. Şimdi devam ettiğimde bir sonraki kesmede sayaç on
> olacak, saniyelik koşul tutacak ve ekrana satır basılacak.

**F5**

👁️ **GÖSTER:** QEMU terminalinde `[tick 10] uptime = 1 s` satırı.

🎙️ **SÖYLE:**

> İşte. On saniye beklemeden o kod yolunu test ettim. Gerçek bir projede
> nadiren oluşan hata senaryolarını böyle test edersiniz — koşulu zorlayarak,
> beklemeden.

## 9.4 Senaryo C: Koşullu breakpoint

🎙️ **SÖYLE:**

> Aynı şeyin daha zarif bir yolu da var: breakpoint'e **koşul** vermek.

👁️ **GÖSTER:** Satır **151**'deki `if` satırına breakpoint koy → **sağ tık** →
**Edit Breakpoint** → **Expression** seç.

⌨️ **YAZ** (koşul alanına):
```
now == 10
```

**F5** — bir kez.

🎙️ **SÖYLE:**

> GDB bu satıra on kez uğrayacak ama **sadece koşul tuttuğunda duracak.** Tek
> tuşla istediğim ana geldim. Bu, gerçek hata avında en çok kullanılan özellik.

## 9.5 Senaryo D: Donanıma doğrudan bakmak

🎙️ **SÖYLE:**

> Son olarak belleğe, yani donanımın kendisine doğrudan bakalım.

⌨️ **YAZ:**
```
-exec x/2xw 0x0200bff8
```

🎙️ **SÖYLE:**

> Bu adres `mtime` — saatin kendisi. Aynı komutu tekrar çalıştırıyorum.

⌨️ **YAZ:** (aynı komutu tekrar)
```
-exec x/2xw 0x0200bff8
```

🎙️ **SÖYLE:**

> Değer **değişti.** Çünkü saat biz debug ederken bile sayıyor — durdurulamaz
> bir donanım sayacı.

⌨️ **YAZ:**
```
-exec x/2xw 0x02004000
```

🎙️ **SÖYLE:**

> Bu da `mtimecmp`, yani alarm kolunun kurulu olduğu değer. Şu an `mtime`'dan
> yüz milisaniye ileride.
>
> Bunlar fonksiyon çağrısı değil, doğrudan donanım register'ı. Gerçek kartta
> bu adresler `0x44000000` tabanında olacak — ve kodun tek satırı değişmeyecek,
> çünkü kodda bu sayılar yazmıyor, `platform.h`'deki isimler yazıyor.

## 9.6 Panel özeti

👁️ **GÖSTER:** Sol taraftaki panelleri sırayla işaret et.

🎙️ **SÖYLE:**

> Debug tarafında kullanılabilir olan her şey var:
>
> **VARIABLES** — lokal değişkenler, otomatik dolu.
> **WATCH** — global değişkenler ve işlemcinin kontrol register'ları; buraya
> `g_tick_count`, `$mcause`, `$mie` gibi şeyleri elle ekliyorum.
> **CALL STACK** — demin gösterdiğim panel.
> **BREAKPOINTS** — koşullu breakpoint'lerin yönetildiği yer.
>
> Ayrıca adım adım çalıştırma, satır atlama, fonksiyona girme ve assembly
> görünümü de çalışıyor — `startup.S` satır satır adımlanabiliyor.

💡 **NOT:** WATCH panelinde CSR'lar **onluk** görünür. `$mcause` =
`-2147483641` yazarsa paniklemeyin, bu `0x80000007`'nin onluk hali. Videoda
gösterirsen bunu söyle, yoksa izleyen kafası karışır.

**Debug'ı bitir:** **Shift + F5**

---

# SAHNE 10 — DEMO 4: Kritik satırı bozalım (2 dk)

🎙️ **SÖYLE:**

> Son demo. Sahne 8'de "satır 87 silinirse ne olur, göstereceğim" demiştim.
> Şimdi gösteriyorum.

👁️ **GÖSTER:** `main.c` satır **87**'yi yorum yap:

```c
/* timer_schedule_next(); */
```

⌨️ **YAZ:**
```powershell
mingw32-make
mingw32-make run
```

👁️ **GÖSTER:** Banner basılıyor, `Zamanlayici kesmesi aktif...` satırı
geliyor, sonra **hiçbir şey.**

🎙️ **SÖYLE:**

> Banner basıldı, "zamanlayıcı kesmesi aktif" yazdı — ve sessizlik. Hiç tick
> satırı yok.
>
> Sebep tam olarak anlattığım şey: alarm bir kez çaldı, sayaç bir oldu, ama
> kimse alarmı yeniden kurmadı. `mtimecmp` geçmişte kaldı, bir daha asla
> tetiklenmeyecek. Ana döngü `wfi` ile sonsuza kadar uyuyor.
>
> Bu, gömülü sistemlerde çok tipik bir hata ve **hiçbir hata mesajı
> vermiyor** — sistem sadece susuyor. Ortamın değeri de burada: bu hatayı kart
> gelmeden, bugün, debugger'la bulabiliyoruz.

⌨️ **YAZ:** `Ctrl+A` → `X`, sonra:
```powershell
copy main.c.yedek main.c
mingw32-make
```

🎙️ **SÖYLE:**

> Kodu geri alıyorum ve yeniden derliyorum.

---

# SAHNE 11 — Otomatik doğrulama (1 dk)

⌨️ **YAZ:**
```powershell
powershell -ExecutionPolicy Bypass -File tools\smoke-test.ps1
```

👁️ **GÖSTER:** `10 / 10 kontrol gecti`

🎙️ **SÖYLE:**

> Son olarak: ortamın kendini test eden bir betiği var. On kontrol yapıyor —
> derleme çalışıyor mu, firmware üretildi mi, QEMU doğru çıktıyı basıyor mu,
> GDB bağlanabiliyor mu, kesme vektörü doğru kurulmuş mu, zamanlayıcı
> sayıyor mu, değişken dışarıdan değiştirilebiliyor mu, RTG-4 hedefi
> derleniyor mu.
>
> Şu an **on üzerinden on** geçiyor ve çıkış kodu döndürüyor — yani bir CI
> sistemine olduğu gibi bağlanabilir. Ekip bir şeyi bozduğunda bunu hemen
> öğrenir.

---

# SAHNE 12 — Kapanış ve yol haritası (1,5 dk)

🎙️ **SÖYLE:**

> Özetleyeyim. Yapılan iş şu:
>
> RTG-4 için, kart gelmeden çalışan bir geliştirme ve simülasyon ortamı kurdum.
> VSCode'a entegre; **Ctrl+Shift+B** derliyor, **F5** debug başlatıyor. Üzerinde
> "Hello, World!" basan ve zamanlayıcı kesmesiyle her saniye rapor üreten bir
> uygulama koşuyor. Breakpoint, register inceleme, değişkeni çalışma anında
> değiştirme — hepsi çalışıyor. Her değişiklikten sonra kendini test eden bir
> betik var.
>
> İşlemcinin komut kümesi ve kesme mimarisi gerçek çipte **birebir aynı.**
> Farklı olan çevre birim adresleri; onları tek bir dosyada topladım.
>
> Sıradaki adımlar:

| Aşama | Ne | Durum |
|---|---|---|
| **1** | Bu ortam | ✅ **Bitti** |
| **2** | `platform.h`'deki RTG-4 adreslerini Libero raporundan doğrula — **5 sayı** | Kart gelmeden yapılabilir |
| **3** | Gerçek kartta JTAG ile çalıştır ve debug et | Kart bekleniyor |
| **4** | *(Opsiyonel)* QEMU'ya gerçek Mi-V makine modeli yaz | Haftalar sürer, ancak çevre birim yazılımı kritikse |

🎙️ **SÖYLE:**

> İkinci aşama için ihtiyacım olan tek şey FPGA tarafından **beş sayı**: RAM
> başlangıç adresi, zamanlayıcı adresi, seri port adresi ve iki saat
> frekansı. Bunlar gelirse ortam gerçek tasarımla hizalanmış olur.
>
> Üçüncü aşamada kaynak kod ve derleme sistemi **değişmiyor** — sadece debug
> bağlantısı QEMU yerine JTAG'a gidiyor.
>
> Teşekkürler.

---

# EK A — Söylemekten kaçınacağın 5 cümle

| ❌ Deme | ✅ De |
|---|---|
| "RTG-4'ü simüle ediyoruz" | "RTG-4'ün içindeki RISC-V işlemciyi hedefliyoruz" |
| "Gerçek kartta test ettim" | "Gerçek kart hedefi için **derlendiğini** doğruladım" |
| "Kart gelince kod doğrudan çalışır" | "Kod derlenir; adreslerin doğrulanması gerekiyor" |
| "RTG-4 işlemcisi" | "RTG-4 FPGA'si ve içindeki Mi-V soft-core'u" |
| "QEMU'da RTG-4 var" | "QEMU'da RISC-V var, RTG-4 yok; RISC-V'yi hedefledik" |

---

# EK B — Olası sorular ve cevapları

**S: QEMU'da zaten RISC-V vardı, bu kadar iş neden gerekti?**
> QEMU işlemciyi veriyor, firmware'i vermiyor. Bare-metal'de başlangıç kodu,
> bellek yerleşimi, kesme vektörü, UART sürücüsü ve derleme sistemi yazılım
> tarafının işi. QEMU'nun verdiği RISC-V, üzerine hiçbir şey kurulmamış boş
> bir işlemci.

**S: Bu ortam gerçek kartın yerini tutar mı?**
> Yazılım mantığı için büyük ölçüde evet. Donanım davranışı için hayır ve bunu
> hiç iddia etmiyorum. Çevre birim davranışı, zamanlama hassasiyeti ve fiziksel
> etkiler gerçek kartta test edilmek zorunda.

**S: Kart gelince ne kadar iş var?**
> Kaynak kodda sıfır. `platform.h`'de beş sayının doğrulanması, bir de
> `launch.json`'da debug bağlantısının OpenOCD'ye çevrilmesi.

**S: Neden `printf` yok?**
> `printf` altında işletim sistemi çağrıları bekliyor ve ikili boyutu çok
> büyütüyor. Onun yerine UART'a doğrudan yazan küçük fonksiyonlar yazdım.
> Gerekirse newlib bağlanabilir, bu bir tercih meselesi.

**S: Başka alternatif var mıydı?**
> Intel Simics değerlendirildi, cihaz modelleri açısından daha güçlüydü ama
> **lisans alınamadı.** Renode da Microchip platformlarını destekliyor ancak
> QEMU istendiği için o yönde ilerledim; istenirse değerlendirilebilir.

**S: Bu ortam başka bilgisayarda çalışır mı?**
> `tools/setup.ps1` her şeyi tek komutla kuruyor, yönetici yetkisi gerekmiyor.
> Taşınabilirlik ayrıntıları `KULLANIM.md`'de.

---

# EK C — Komut listesi (kopyala-yapıştır)

```powershell
# Çekim öncesi
copy main.c main.c.yedek
mingw32-make clean

# Sahne 3
riscv-none-elf-gcc --version
qemu-system-riscv32 --version

# Sahne 6
mingw32-make
mingw32-make info
mingw32-make PLATFORM=PLATFORM_RTG4_MIV
mingw32-make

# Sahne 7
mingw32-make run                  # çıkış: Ctrl+A sonra X

# Sahne 10
mingw32-make
mingw32-make run
copy main.c.yedek main.c
mingw32-make

# Sahne 11
powershell -ExecutionPolicy Bypass -File tools\smoke-test.ps1
```

**`mingw32-make` hedeflerinin tamamı:**

| Komut | Ne yapar |
|---|---|
| `mingw32-make` | Derler (varsayılan hedef `all`) |
| `mingw32-make run` | QEMU'da çalıştırır — çıkış: **Ctrl+A** sonra **X** |
| `mingw32-make debug` | QEMU'yu durdurulmuş + GDB sunucusuyla başlatır |
| `mingw32-make gdb` | GDB'yi bağlar |
| `mingw32-make clean` | Üretilen dosyaları siler |
| `mingw32-make info` | Derleyici / platform / boyut özeti |
| `mingw32-make help` | Hedeflerin listesini basar |
| `mingw32-make PLATFORM=PLATFORM_RTG4_MIV` | **Gerçek RTG-4 hedefi için** derler |

> `rebuild` bir Makefile hedefi **değil** — sadece VSCode task'ı
> (`clean` + `build` zinciri).

**DEBUG CONSOLE komutları:**
```
-exec p/x $mcause                 kesme mi hata mı
-exec p g_tick_count              sayacı oku
-exec p/x $mepc                   kesilen komutun adresi
-exec set var g_tick_count = 9    değişkeni dışarıdan değiştir
-exec x/2xw 0x0200bff8            mtime  (saatin kendisi)
-exec x/2xw 0x02004000            mtimecmp (alarm kolu)
-exec info registers              tüm register'lar
```

---

# EK D — Tüm proje dosyaları (hiçbiri atlanmadı kontrolü)

Videoda her birine değiniliyor; bu tablo kontrol listesi.

## Kaynak kod — 7 dosya

| Dosya | Ne yapıyor | Sahne |
|---|---|---|
| `platform.h` | **Tüm donanım adreslerinin isim listesi.** QEMU/RTG-4 anahtarı | **5.3** |
| `startup.S` | İşlemci açılınca ilk çalışan kod + `trap_entry` | **5.1** |
| `main.c` | Uygulama: banner, saniye sayma, `trap_handler` | **7.5, 8** |
| `uart.c` | Seri port sürücüsü — NS16550A **ve** CoreUARTapb | **5.5** |
| `uart.h` | `uart.c`'nin fonksiyon listesi | **5.5** |
| `linker.ld` | Hangi kod hangi adrese gidecek + `ASSERT` güvenlik ağı | **5.2** |
| `riscv_csr.h` | CSR erişim makroları + bit tanımları | **5.4** |

## Derleme — 3 dosya

| Dosya | Ne yapıyor | Sahne |
|---|---|---|
| `Makefile` | 6 hedef, bayraklar, `platform.stamp` mekanizması | **5.6** |
| `config.mk` | **Üretilen.** Bu makineye özgü araç yolları | **5.7** |
| `platform.stamp` | **Üretilen.** Son derlemenin platformu | **5.6** |

## `.vscode/` — 5 dosya

| Dosya | Ne sağlıyor | Sahne |
|---|---|---|
| `tasks.json` | 8 task: build, RTG4 build, rebuild, clean, run, qemu başlat/durdur, smoke test | **4** |
| `launch.json` | **F5** debug — 2 konfigürasyon | **4, 9.1** |
| `c_cpp_properties.json` | IntelliSense, 2 konfigürasyon (QEMU / RTG4) | **4** |
| `settings.json` | Makefile'da tab zorunlu, `.S`'e breakpoint izni | **4** |
| `extensions.json` | `ms-vscode.cpptools` önerisi | **4** |

## `tools/` — 5 dosya

| Dosya | Ne yapıyor | Sahne |
|---|---|---|
| `setup.ps1` | Sıfırdan kurulum, tek komut | **3, 5.7** |
| `qemu-debug.ps1` | QEMU + GDB sunucusu, **port bekler** | **5.7, 9.1** |
| `qemu-stop.ps1` | Arkadaki QEMU'ları kapatır | **5.7** |
| `smoke.gdb` | 8 adımlı GDB doğrulama betiği | **5.7** |
| `smoke-test.ps1` | Uçtan uca 10 kontrol, exit code | **5.7, 11** |

## Firmware çıktıları — 5 dosya (hepsi üretilen)

| Dosya | Ne işe yarıyor | Sahne |
|---|---|---|
| `firmware.elf` | Debug bilgisi içeren asıl dosya — QEMU ve GDB bunu kullanır | **6** |
| `firmware.bin` | Ham ikili | **6** |
| `firmware.hex` | **Gerçek kartı programlama formatı** — Libero/eNVM | **6** |
| `firmware.map` | Neyin hangi adrese gittiği | **6** |
| `firmware.lst` | C kodunun karşılığındaki assembly | **6** |

## Dokümantasyon

| Dosya | Kime |
|---|---|
| `README.md` | İnsan/müdür tarafı: yol haritası, kesme diyagramı, sorun giderme |
| `aciklama.md` | Konuyu hiç bilmeyen biri için sıfırdan anlatım |
| `KULLANIM.md` | İlerisi: taşınabilirlik, yeni/karmaşık C projesi, CI |
| `CLAUDE.md` | Teknik devir-teslim notları |
| `video.md` | **Bu dosya** |

---

# EK E — Breakpoint tablosu

| Satır | Ne var | Hangi sahne |
|---|---|---|
| `main.c` **86** | `g_tick_count++` | 9.2 |
| `main.c` **148** | `now = g_tick_count` | 9.3 |
| `main.c` **151** | saniyelik `if` — koşullu | 9.4 |
| `main.c` **87** | kritik satır (yorum yapılacak) | 10 |
| `startup.S` **18** | ilk çalışan komut | 5.1 (göster) |
| `startup.S` **31** | yığın kurulumu | 5.1 (göster) |
| `startup.S` **64** | kesme vektörü | 5.1 (göster) |

---

# EK F — Çekim sonrası kontrol listesi

- [ ] `main.c` satır **87** yorumdan çıkarıldı mı?
- [ ] `copy main.c.yedek main.c` yapıldı mı?
- [ ] **QEMU hedefine geri dönüldü mü?** → `mingw32-make`
- [ ] Tüm breakpoint'ler silindi mi? (koşullu olanlar dahil)
- [ ] Arkada QEMU kalmadı mı? → `powershell -ExecutionPolicy Bypass -File tools\qemu-stop.ps1`
- [ ] Son doğrulama: `tools\smoke-test.ps1` → **10 / 10 kontrol gecti**
