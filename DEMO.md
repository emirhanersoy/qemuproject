# DEMO.md — Video çekim senaryosu

> Projeyi baştan sona anlatan video için **sahne sahne kurgu**: ne söyleyeceğin,
> ekranda ne olacak, hangi komutu yazacaksın.
>
> **Kullanım:** Bunu ikinci bir ekranda (veya telefonda) açık tut, sahne sahne
> ilerle. Her sahnenin başında **[EKRAN]** ne göstereceğini, **[SÖYLE]** ne
> anlatacağını, **[YAZ]** hangi komutu gireceğini belirtiyor.
>
> **Toplam süre:** ~22 dakika (tam sürüm) · ~8 dakika (kısa sürüm, bkz. §K)
>
> Satır numaraları `main.c`'nin **18 Ekim 2026 akşamı** hâline göre. Dosyayı
> değiştirirsen numaraları tazele.

---

## SAHNE 0 — Çekim öncesi hazırlık (kayıt yok)

### 0.1 Teknik doğrulama — bunu atlama

```powershell
powershell -ExecutionPolicy Bypass -File tools\smoke-test.ps1
```

**10/10 görmeden kamerayı açma.** Geçmiyorsa video çekmek değil, sorunu
bulmak gerekir.

```powershell
tools\qemu-stop.ps1          # arka planda kalmis QEMU varsa temizle
```

Sonra VSCode'u **yeniden başlat** (PATH'i taze görsün) ve bir kez F5 dene.

### 0.2 Ekran düzeni

- [ ] Terminal yazı boyutunu büyüt: **Ctrl + `+`** (projeksiyonda/videoda okunmalı)
- [ ] VSCode zoom: **Ctrl + Shift + `+`** bir iki kademe
- [ ] Gereksiz sekmeleri kapat; sadece şunlar açık kalsın:
      `main.c`, `platform.h`, `startup.S`, `Makefile`
- [ ] Sol panelde dosya ağacı görünür olsun (dosya turu için gerekli)
- [ ] Bildirimleri kapat (Windows odak yardımcısı), telefon sessize
- [ ] Tarayıcı sekmelerin, e-postan ekranda görünmesin

### 0.3 Ekranda **göstermemen** gerekenler

| Dosya | Neden |
|---|---|
| `SUNUM.md` **Bölüm B** | "Müdüre şunu söyleme" notları var. Kamerada açılmasın. |
| `CLAUDE.md` | Yapay zekâ devir-teslim dosyası. Göstermek istemezsen sekmeyi kapat; göstermek istersen de sorun yok, kararı senin. |
| `config.mk` | Zararsız, sadece senin makinenin yolları. İstersen göster. |

### 0.4 Çekim stratejisi — **tek seferde çekmeye çalışma**

Sahneleri **ayrı ayrı çek, sonra birleştir.** Bir sahne patlarsa sadece onu
tekrar çekersin. Tek uzun kayıtta 18. dakikada yapılan hata tüm videoyu
baştan çektirir.

Önerilen bölünme: `Sahne 1–2` (anlatım) · `Sahne 3` (dosya turu) ·
`Sahne 4` (VSCode) · `Sahne 5–10` (demolar, her biri ayrı klip) ·
`Sahne 11–12` (kapanış).

### 0.5 Yedek plan: ekran kaydının yanında bir de "garanti kayıt"

Demoların bir kez **sorunsuz koştuğu** bir kaydı önce al, kenara koy. Sonra
anlatımlı çekimi yap. Canlı demoda bir şey patlarsa yedek klibi kullanırsın.

---

## SAHNE 1 — Açılış: görev neydi (0:00 – 0:45)

**[EKRAN]** Sadece sen, veya projenin dosya ağacı.

**[SÖYLE]**

> "Bu videoda RTG4 projesi için hazırladığım yazılım geliştirme ve simülasyon
> ortamını anlatacağım. Görev şuydu: ekip RTG4 ile bir proje yapacak, fiziksel
> kart henüz gelmedi, bu yüzden QEMU'da bir ortam kurulacak. Ekip VSCode'da C
> kodu yazacak ve kod çalışacak. Kapsam geniş olmak zorunda değildi, Hello
> World yeterliydi; ayrıca debug yapılabilmesi ve bir interrupt zamanlayıcısı
> kurulabilmesi istendi.
>
> Önce neyi neden seçtiğimizi anlatacağım, sonra dosyaları tek tek tanıtacağım,
> en sonunda da her şeyi canlı çalıştırıp göstereceğim."

**İpucu:** Videonun başında **ne göstereceğini söylemek** izleyiciyi tutar.
"Sonunda canlı çalıştıracağım" cümlesi, dosya turunu dinlemeleri için sebep verir.

---

## SAHNE 2 — Problem ve alternatifler (0:45 – 3:00)

Bu sahne videonun **mühendislik omurgası**. Acele etme.

### 2.1 Temel teknik gerçek

**[EKRAN]** Basit bir görsel yoksa konuşarak anlat; istersen `platform.h`'nin
başındaki yorum bloğunu göster.

**[SÖYLE]**

> "Başlarken anlamam gereken ilk şey şuydu: RTG4 bir işlemci değil, bir FPGA.
> Microchip'in radyasyona dayanıklı uzay FPGA'i. İçinde hazır bir CPU yok.
> İşlemci, FPGA dokusuna tasarımla yerleştirilen bir RISC-V çekirdeği oluyor —
> Microchip bunun için Mi-V adında hazır çekirdekler veriyor.
>
> Bu, ortamı kurarken neyi hedeflemem gerektiğini belirledi: RTG4'ün kendisini
> değil, RTG4 üzerinde koşacak **RISC-V çekirdeğini** hedeflemem gerekiyordu."

### 2.2 Alternatifler tablosu

**[EKRAN]** İstersen bu tabloyu bir slayt olarak hazırla; yoksa anlat.

| Alternatif | Neden seçilmedi / seçildi |
|---|---|
| **Intel Simics** | Cihaz seviyesinde modelleme verirdi — en güçlü seçenek. **Lisans alınamadı.** |
| **QEMU'ya RTG4/Mi-V makine modeli yazmak** | Teknik olarak mümkün, **haftalar** sürer. Kapsamın çok ötesinde. |
| **Kartın gelmesini beklemek** | Ekip o sürede yazılım tarafında ilerleyemezdi. |
| **QEMU `virt` makinesi** ✅ | Komut kümesi ve kesme mimarisi RTG4'teki çekirdekle **birebir aynı**. Bugün çalışıyor, maliyeti sıfır. |

**[SÖYLE]**

> "QEMU'nun içinde RISC-V desteği var, bu doğru. Ama QEMU'da hazır bir RTG4
> veya Mi-V makine modeli **yok**. QEMU'nun verdiği şey `virt` adında genel
> amaçlı bir RISC-V platformu. Yani kutudan çıkan şey 'RTG4 simülatörü' değil,
> 'RISC-V işlemci simülatörü'. Aradaki boşluğu kapatmak bu projenin işi oldu."

### 2.3 Hangi katman aynı, hangisi farklı — **videonun en önemli tablosu**

| Katman | RTG4 / Mi-V | Bu ortam | Aynı mı? |
|---|---|---|---|
| Komut kümesi (ISA) | RV32I + M, A, C | `rv32imac` | **Birebir aynı** |
| Kesme mimarisi | mtvec/mstatus/mie/mcause/mret | aynı CSR'lar | **Birebir aynı** |
| Zamanlayıcı mantığı | CLINT mtime/mtimecmp | CLINT mtime/mtimecmp | **Mantık aynı** |
| Zamanlayıcı adresi | `0x4400_0000` | `0x0200_0000` | Farklı |
| Seri port | CoreUARTapb | NS16550A | Farklı |
| RAM tabanı | `0x8000_0000` | `0x8000_0000` | Aynı |

**[SÖYLE]**

> "Üst iki satır bu projenin neden anlamlı olduğunu anlatıyor: işlemcinin
> komutları ve kesme mimarisi birebir aynı. Farklı olan şey çevre birimlerin
> adresleri. Bu da çözülebilir bir problem — ve projenin merkezî tasarım
> kararı tam burada."

### 2.4 Merkezî karar

**[SÖYLE]**

> "Uygulama kodu **hiçbir yerde çıplak donanım adresi kullanmıyor.** Tüm
> adresler tek bir dosyada, isimli sabitler olarak duruyor. Hedefi
> değiştirmek tek bir derleme parametresi. Bunu sonunda canlı göstereceğim."

---

## SAHNE 3 — Dosya turu (3:00 – 7:00)

**Sıralama önemli:** dosyaları alfabetik değil, **bağımlılık sırasına** göre
tanıt — işlemcinin açılış sırasıyla aynı. İzleyici hikâyeyi takip eder.

**[EKRAN]** Sol panelden dosyayı aç, ilgili satırlara kaydır.

### 3.1 `platform.h` — "projenin kalbi" (60 sn)

**[EKRAN]** `platform.h`, iki `#if` bloğu görünecek şekilde.

**[SÖYLE]**

> "En önemli dosya bu. İki platform tanımı var: biri QEMU, biri gerçek RTG4.
> Her ikisinde de aynı isimler tanımlı — RAM tabanı, zamanlayıcı adresi, seri
> port adresi, saat frekansı. Uygulama kodu bu isimleri kullanıyor, sayıları
> bilmiyor.
>
> RTG4 bloğundaki adreslerin yanında bir uyarı yorumu var: bunlar Mi-V
> referans tasarımlarının tipik değerleri. RTG4 bir FPGA olduğu için çevre
> birimlerin adresi tasarıma göre değişir, bu yüzden kart geldiğinde donanım
> tasarımından doğrulanmaları gerekiyor. Bunu doğru biliyormuş gibi
> sunmuyorum."

**Göster:** `#define CLINT_BASE 0x02000000UL` (QEMU) ve `0x44000000UL` (RTG4)
satırlarını yan yana.

### 3.2 `linker.ld` — kod hangi adrese gidiyor (45 sn)

**[SÖYLE]**

> "Derleyici `.o` dosyaları üretir ama 'hangi kod hangi adrese gidecek'
> sorusunu linker script cevaplar. Gömülü sistemde bu dosya olmadan çalışan
> bir imaj üretemezsin: işlemci resetten sonra belirli bir adresten komut
> okumaya başlar, kodu tam oraya koymak zorundasın.
>
> Burada RAM `0x80000000`'da başlıyor, yığın 16 KB, heap 4 KB. Bir de şu var:
> kod, yığın ve heap RAM'e sığmazsa **derleme anında hata veriyor** —
> çalışma anında anlaşılmaz bir çökme yaşamak yerine."

**Göster:** `MEMORY { RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 8M }` ve
alttaki `ASSERT(...)` satırı.

### 3.3 `startup.S` — işlemci gözünü açtığında (75 sn)

Bu dosya videonun en öğretici kısmı. Yedi adımı tek tek göster.

**[SÖYLE]**

> "İşlemci resetten çıktığında C dili için gerekli hiçbir şey hazır değildir:
> yığın yoktur, global değişkenler sıfırlanmamıştır. Bu dosya o ortamı kurup
> `main`'e atlıyor. Yedi adım var:
>
> Kesmeleri kapat, global pointer'ı kur, yığın işaretçisini kur, `.data`
> bölümünü kopyala, `.bss`'i sıfırla, **kesme vektörünü kur**, ve `main`'e atla."

**Göster:** `csrw mtvec, t0` satırı (adım 6).

> "Bu satır kritik: kesme olduğunda işlemcinin atlayacağı adresi söylüyoruz.
> Birazdan debugger'da bu register'ın değerini canlı okuyacağım."

Sonra `trap_entry` kısmına kaydır:

> "Dosyanın ikinci yarısı kesme giriş noktası. **Neden assembly?** İki sebep:
> birincisi kesme bir C fonksiyonunun ortasında aniden olur, kesilen kodun
> geçici register'larını bozmamak için önce onları yığına kaydetmek gerekir.
> İkincisi, normal C fonksiyonu `ret` ile döner ama kesmeden dönmek için
> `mret` gerekir — ve `mret` aynı zamanda kesmeleri geri açar. `ret` ile
> dönseydik kesmeler bir daha hiç açılmazdı. Bu iki şey C'de yapılamaz."

### 3.4 `uart.c` / `uart.h` — ekrana yazı (30 sn)

**[SÖYLE]**

> "Seri port sürücüsü. Dikkat: `printf` kullanmıyoruz. Bare-metal'de
> standart kütüphanenin `printf`'i hem büyüktür hem de altında işletim
> sistemi çağrıları bekler. Onun yerine doğrudan donanım register'ına byte
> yazan kendi fonksiyonlarımız var.
>
> Bu dosyada iki sürücü var — QEMU'nun portu ve RTG4'ün portu. Hangisinin
> derleneceği `platform.h`'ye göre seçiliyor, ama **dışarıya verdiği arayüz
> aynı**. Uygulama kodu hangi platformda olduğunu bilmiyor."

### 3.5 `main.c` — asıl uygulama (60 sn)

Üç yere bak:

**a) Satır 7 — periyot ayarı**
```c
#define TICK_HZ   10u     /* saniyede 10 kesme = 100 ms periyot */
```
> "Kesme periyodu tek bir sabitle ayarlanıyor. Şu an saniyede 10 kesme,
> yani 100 milisaniye."

**b) Satır 77–93 — kesme işleyicisi**
> "Kesme geldiğinde çalışan C fonksiyonu. `mcause` register'ını okuyup
> kesme mi hata mı olduğuna bakıyor. Zamanlayıcı kesmesiyse sayacı artırıyor
> ve **bir sonraki kesmeyi kuruyor**."

**Satır 87'yi göster — videoda vurgula:**
```c
timer_schedule_next();  /* periyodikligi saglayan satir */
```
> "Bu satır kritik. RISC-V zamanlayıcısı tek seferliktir, kendini otomatik
> yenilemez. Bu satır olmazsa kesme ya bir kez olur ya da sonsuz tetiklenir.
> İsterseniz sonunda bunu bozup ne olduğunu da gösterebilirim."

**c) Satır 130–159 — ana döngü**
> "Ana döngü `wfi` komutuyla işlemciyi kesme gelene kadar uyutuyor. Boş
> döngüde beklemek yerine bunu kullanmak gerçek donanımda güç tasarrufu,
> QEMU'da da ana makinenin işlemcisini yormuyor.
>
> Bir de şuna dikkat: sayaç değişkeni `volatile`. Kesme içinde değiştiği için
> bu şart — `volatile` olmasa derleyici değeri register'da önbellekler ve ana
> döngü değişimi hiç görmezdi."

### 3.6 `Makefile` (30 sn)

**[SÖYLE]**

> "Derleme sistemi. Hedefler: `all` derler, `run` QEMU'da çalıştırır, `debug`
> QEMU'yu debugger beklemede başlatır, `clean` temizler.
>
> Bir satırı göstermek istiyorum: mimari seçimi."

**Göster:** `ARCHFLAGS := -march=rv32imac_zicsr_zifencei -mabi=ilp32 ...`

> "`rv32imac` — 32 bit, tamsayı, çarpma-bölme, atomik, sıkıştırılmış
> komutlar. `zicsr` da şart: GCC 12'den sonra CSR komutlarını ayrıca istemek
> gerekiyor, bu olmadan tek bir `csrw` komutu bile derlenmiyor."

### 3.7 `tools/` klasörü (20 sn)

> "Dört yardımcı betik: `setup.ps1` boş bir makinede ortamın tamamını kurar,
> `qemu-debug.ps1` debug sunucusunu başlatır, `qemu-stop.ps1` temizler,
> `smoke-test.ps1` de uçtan uca doğrulama yapar. Sonunda onu da göstereceğim."

---

## SAHNE 4 — VSCode entegrasyonu (7:00 – 9:00)

**[EKRAN]** `.vscode/` klasörünü aç, dosyaları sırayla göster.

**[SÖYLE] açılış:**

> "Görevdeki maddelerden biri 'ben VSCode'da kodumu yazayım ve çalışsın'
> idi. VSCode tarafında dört dosya var, her biri farklı bir işi çözüyor."

### 4.1 `tasks.json` — komutları menüye bağlamak (40 sn)

> "Burada sekiz task tanımlı: derle, RTG4 hedefi için derle, baştan derle,
> temizle, QEMU'da çalıştır, debug sunucusunu başlat, QEMU'yu durdur ve
> smoke test.
>
> 'build' task'ı **varsayılan derleme görevi** olarak işaretli — bu yüzden
> Ctrl+Shift+B doğrudan onu koşturuyor. Yani ekip üyesinin terminal komutu
> öğrenmesi gerekmiyor."

**Göster:** `"group": { "kind": "build", "isDefault": true }`

### 4.2 `launch.json` — F5 ile debug (50 sn)

> "İki debug konfigürasyonu var. Birincisi normal kullanım: F5'e basınca kod
> derlenir, QEMU durdurulmuş halde başlar, GDB bağlanır ve `main` içinde
> durur.
>
> İkincisi daha ilginç: işlemcinin **ilk komutunda**, `startup.S`'in içinde
> durur. Yani reset anından itibaren her komutu izleyebiliyorsun."

**Göster:** `"miDebuggerServerAddress": "localhost:1234"` ve
`"preLaunchTask"` / `"postDebugTask"` satırları.

> "Akış şöyle: `preLaunchTask` QEMU'yu debug sunucusu olarak başlatıyor,
> VSCode GDB'yi `localhost:1234`'e bağlıyor, oturum bitince `postDebugTask`
> QEMU'yu kapatıyor. Kullanıcı sadece F5'e basıyor."

### 4.3 `c_cpp_properties.json` — IntelliSense (20 sn)

> "Kod tamamlama ve 'tanıma git' özelliğinin çalışması için. İki
> konfigürasyon var, QEMU ve RTG4 için — sağ alttan seçince IntelliSense
> o platformun tanımlarına göre çalışıyor, yani `platform.h`'de hangi
> bloğun aktif olduğunu editörde de görüyorsun."

### 4.4 `settings.json` — küçük ama kritik ayarlar (20 sn)

> "Üç şey yapıyor: Makefile'da girintinin **sekme** olmasını zorluyor —
> Makefile boşlukla girintilenirse derleme hata verir, klasik bir tuzak.
> Assembly dosyalarına breakpoint koymayı açıyor. Ve derleme çıktısı
> dosyalarını dosya ağacından gizliyor."

---

## SAHNE 5 — DEMO A: Derleme (9:00 – 10:15)

**[EKRAN]** `main.c` açık, satır 118 görünür.

**[YAP]** Canlı bir değişiklik yap — **sadece burada**:

```c
    uart_puts(" Hello, World!\n");
```
satırını, örneğin:
```c
    uart_puts(" Hello, World!  --  demo kaydi\n");
```

> **Neden sadece burası?** `print_banner()` içindeki bir yazı en güvenli
> nokta: derlemeyi kıramaz, mantığı bozamaz. Kesme kodunu veya `platform.h`'yi
> kamera karşısında kurcalamayı deneme.

**[YAZ]** **Ctrl + Shift + B**

**[EKRAN]** Terminalde:
```
[CC]  main.c
[LD]  firmware.elf
Memory region         Used Size  Region Size  %age Used
             RAM:       22544 B         8 MB      0.27%
   text	   data	    bss	    dec	    hex	filename
   2042	      0	  20492	  22534	   5806	firmware.elf
Hazir: firmware.elf + .bin .hex .map .lst
```

**[SÖYLE]**

> "Tek tuşla derlendi. Çıktıda iki şeye dikkat: üretilen kod iki kilobayt
> civarında ve 8 megabaytlık RAM'in yüzde 0.27'sini kullanıyoruz. Yani
> ortamın kendisi neredeyse hiç yer kaplamıyor, geri kalanı uygulamaya
> kalıyor.
>
> Bir de linker dört dosya üretiyor: `.elf` debug için, `.bin` ham ikili,
> `.hex` gerçek karta programlamak için — bu zaten Libero'nun bellek
> programlama akışına bağlanabilir formatta — ve `.lst` de C kodunun
> karşılığı assembly."

**İsteğe bağlı (+20 sn, çok etkili):** `firmware.lst` dosyasını aç, `main`
fonksiyonunu bul. C satırlarının altında karşılık gelen RISC-V komutları
görünür.

> "Bu dosya C kodunun hangi komutlara dönüştüğünü satır satır gösteriyor.
> Gömülü tarafta hata ararken çok işe yarıyor."

---

## SAHNE 6 — DEMO B: Çalıştırma (10:15 – 11:45)

**[YAZ]**
```powershell
mingw32-make run
```
(veya VSCode'dan "run (QEMU)" task'ı)

**[EKRAN]** Çıktı akar:
```
===========================================
 Hello, World!  --  demo kaydi
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

**[ÖNEMLİ]** **En az 5–6 saniye bekle, satırların canlı akmasına izin ver.**
Bu, kesmenin gerçekten çalıştığının en görsel kanıtı ve videonun en ikna
edici anı. Acele edip kesme.

**[SÖYLE]**

> "Az önce değiştirdiğim yazı ekranda. Banner'daki değerler `platform.h`'den
> geliyor — kod kendi bellek haritasını yazdırıyor, yani hangi platform için
> derlendiği çalışma anında da görünüyor.
>
> Alttaki satırlar asıl önemli kısım: bunlar bir döngünün saymasıyla
> oluşmuyor. İşlemci `wfi` ile uyuyor. Her 100 milisaniyede donanım
> zamanlayıcısı bir kesme üretiyor, kesme işleyicisi sayacı artırıyor, ana
> döngü de her tam saniyede bir satır basıyor. Ekrandaki her satır on tane
> gerçek donanım kesmesinin sonucu."

**[YAZ]** Çıkış: **Ctrl+A**, tuşları bırak, sonra **X**

> "QEMU'dan çıkış Ctrl+A sonra X — bunu söylemek lazım, yoksa terminalde
> sıkışıp kalınıyor."

---

## SAHNE 7 — DEMO C: Debug (11:45 – 14:45)

Bu, müdürün özellikle istediği iki maddeden biri. Acele etme.

### 7.1 Breakpoint koy ve F5

**[YAP]** `main.c` **satır 132** (`uint32_t reported = 0;`) soluna tıkla →
kırmızı nokta.

**[YAZ]** **F5**

**[EKRAN]** Olanları anlat:
- Alt tarafta task terminali açılır, QEMU başlar
- Debug araç çubuğu görünür
- Kod `main` içinde durur, satır sarı vurgulu

**[SÖYLE]**

> "F5'e bastım. Arka planda üç şey oldu: kod derlendi, QEMU işlemciyi
> durdurulmuş halde başlattı ve bir debug sunucusu açtı, VSCode da GDB'yi o
> sunucuya bağladı. Şimdi `main` fonksiyonunun içinde durmuş durumdayız.
>
> Dikkat: bu kod bu bilgisayarın işlemcisinde çalışmıyor. Simüle edilen bir
> RISC-V işlemcisinde çalışıyor. Ama debug deneyimi normal VSCode debug'ından
> farksız."

### 7.2 Temel debug yetenekleri (45 sn)

**[YAP]** Sırayla göster:

1. **Variables** paneli → `reported`, `now` değerleri
2. **F10** ile birkaç satır adımla
3. **F11** ile bir fonksiyonun içine gir (`uart_init` veya `timer_start`)
4. **Call Stack** panelinde çağrı zinciri

**[SÖYLE]**

> "Değişkenler, satır satır adımlama, fonksiyon içine girme, çağrı
> yığını — hepsi var."

### 7.3 Register ve CSR okuma — **gömülü tarafın farkı** (60 sn)

**[YAP]** **Watch** paneline şunları ekle:
```
$mtvec
$mcause
$mepc
$mie
```

**[SÖYLE]**

> "Gömülü debug'ın normal uygulama debug'ından ayrıldığı yer burası:
> işlemcinin kontrol register'larını canlı okuyabiliyoruz.
>
> `mtvec`'e bakın — bu, kesme olduğunda işlemcinin atlayacağı adres.
> `startup.S`'te kurduğumuz değer. Hex olarak bakalım."

**[YAZ]** Debug Console'a:
```
-exec p/x $mtvec
```
Beklenen: `0x8000007c`

**[YAZ]** Sonra:
```
-exec p/x &trap_entry
```
Beklenen: aynı değer, `0x8000007c`

**[SÖYLE]**

> "İkisi aynı. Yani `startup.S`'teki kesme vektörü kurulumu gerçekten
> çalışmış, işlemci kesme geldiğinde bizim fonksiyonumuza atlayacak. Bu,
> gözle kodu okuyarak değil, canlı donanımdan okuyarak doğrulanmış bir şey."

> **Not:** Watch panelinde CSR'lar **onluk** görünür. `$mcause` için
> `-2147483641` gibi bir sayı görürsen bu `0x80000007`'nin onluk karşılığı.
> Hex görmek için Debug Console'da `-exec p/x $mcause`.

### 7.4 Debugger'dan müdahale (30 sn)

**[YAZ]** Debug Console'a:
```
-exec set var g_tick_count = 4242
-exec p g_tick_count
```

**[SÖYLE]**

> "Sadece izlemiyoruz, müdahale de edebiliyoruz. Değişkenin değerini
> dışarıdan değiştirdim. Bu, test ederken çok işe yarıyor: bir durumu
> oluşmasını beklemek yerine doğrudan o duruma zorlayabiliyorsun."

---

## SAHNE 8 — DEMO D: Kesmenin içine girmek (14:45 – 17:15)

Bu, "interrupt zamanlayıcısı" maddesinin kanıtı ve videonun teknik zirvesi.

### 8.1 Kesme işleyicisine breakpoint

**[YAP]** `main.c` **satır 79** (`uint32_t mcause = csr_read(mcause);`) →
breakpoint koy. Sonra **F5** ile devam ettir.

**[EKRAN]** Breakpoint **kendiliğinden** tetiklenir (en fazla 100 ms içinde).

**[SÖYLE]**

> "Kimseye bir şey yapmadım, devam ettir dedim ve kesme işleyicisinin içinde
> durdu. Çünkü zamanlayıcı 100 milisaniyede bir kesme üretiyor ve işlemci
> otomatik olarak buraya atlıyor."

### 8.2 Kesme bilgilerini oku (60 sn)

**[YAZ]** Debug Console:
```
-exec p/x $mcause
-exec p/x $mepc
-exec p/x $mie
-exec p/x $mstatus
```

Beklenen değerler ve açıklamaları:

| Register | Değer | **[SÖYLE]** |
|---|---|---|
| `mcause` | `0x80000007` | "En üst bit 1: bu bir kesme, hata değil. Alt kısım 7: makine zamanlayıcı kesmesi. İşlemci bize neden buraya geldiğini söylüyor." |
| `mepc` | `0x800003xx` | "Kesmenin böldüğü komutun adresi. Dönülecek yer burası." |
| `mie` | `0x00000080` | "Bit 7 açık — zamanlayıcı kesmesi etkin." |
| `mstatus` | `0x00001880` | "Kesme içindeyiz, o yüzden global kesme biti kapalı ve önceki değeri saklanmış. `mret` ile dönerken geri yüklenecek. Bu, iç içe kesme karmaşasını önleyen donanım davranışı." |

### 8.3 Çağrı yığını — C ve assembly birlikte (30 sn)

**[EKRAN]** **Call Stack** panelini göster:
```
trap_handler()  main.c:79
trap_entry()    startup.S:114
```

**[SÖYLE]**

> "Bu, az önce `startup.S`'te anlattığım şeyin kanıtı. Kesme donanım
> tarafından `trap_entry`'ye atladı — o assembly fonksiyonu — oradan da C
> fonksiyonumuza geçti. Debugger ikisini birlikte gösteriyor, yani assembly
> ve C katmanları arasında kesintisiz gezinebiliyoruz."

### 8.4 Periyodik olduğunu göster (30 sn)

**[YAP]** **F5** ile iki kez daha devam ettir — her seferinde aynı
breakpoint'e düşer.

**[YAZ]**
```
-exec p g_tick_count
```
Değerin arttığını göster.

**[SÖYLE]**

> "Her seferinde tekrar tetikleniyor ve sayaç ilerliyor. Yani kesme
> gerçekten periyodik. Bunu sağlayan şey birazdan göstereceğim tek bir satır."

### 8.5 CLINT register'larını canlı oku (isteğe bağlı, +30 sn)

**[YAZ]**
```
-exec x/2x 0x0200bff8
-exec x/2x 0x02004000
```

**[SÖYLE]**

> "Bunlar zamanlayıcının kendi register'ları — şu anki zaman ve hedef zaman.
> Doğrudan bellek adresinden okuyorum. Gerçek RTG4'te aynı register'lar
> farklı bir adreste olacak, ama mantık birebir aynı."

---

## SAHNE 9 — DEMO E: Platform anahtarı (17:15 – 18:45)

**Videonun en güçlü mühendislik anı bu.** Atlamak olmaz.

**[YAZ]**
```powershell
mingw32-make clean
mingw32-make PLATFORM=PLATFORM_RTG4_MIV
```

**[EKRAN]** Derleme çıktısı — hata yok, boyut biraz farklı.

**[SÖYLE]**

> "Aynı kaynak kodu, bu kez gerçek RTG4 hedefi için derledim. Tek değişen
> şey komut satırındaki bir parametre. `main.c`'nin tek satırı değişmedi,
> kesme mantığının tek satırı değişmedi.
>
> Arka planda olan şey: `platform.h` diğer bloğu aktif etti, seri port
> sürücüsü CoreUARTapb sürümüne geçti, adresler RTG4 değerlerine döndü.
>
> Bu ikiliyi QEMU'da **çalıştıramıyorum** — RTG4'ün adresleri QEMU'da yok,
> bu normal. Ama derlendiğini gösteriyorum, çünkü kart geldiğinde yapılacak
> iş bu: kodu yeniden yazmak değil, bir parametre değiştirmek ve
> `platform.h`'deki beş sayıyı donanım tasarımından doğrulamak."

**[YAZ]** Geri dön:
```powershell
mingw32-make clean
mingw32-make
```

> **Dürüstlük notu (söyle):** "Gerçek kartta hiç denenmedi, sadece derlendi.
> Bu ikisini karıştırmamak önemli."

---

## SAHNE 10 — DEMO F: Otomatik regresyon testi (18:45 – 20:15)

**[YAZ]**
```powershell
powershell -ExecutionPolicy Bypass -File tools\smoke-test.ps1
```

**[EKRAN]** Betik akarken anlat — üç aşaması var:

```
=== A) Derleme ===
  [GECTI    ] derleme

=== B) QEMU'da calistirma (UART ciktisi) ===
  [GECTI    ] hello-world
  [GECTI    ] platform-adi
  [GECTI    ] timer-kesmesi
  [GECTI    ] zaman-dogrulugu

=== C) GDB ile hata ayiklama zinciri ===
  [GECTI    ] gdb-baglanti
  [GECTI    ] mtvec-kurulumu
  [GECTI    ] timer-irq
  [GECTI    ] degisken-yazma
  [GECTI    ] smoke-tamam

=== OZET ===
  10 / 10 kontrol gecti
  TUM KONTROLLER GECTI
```

**[SÖYLE]**

> "Bu betik üç şey yapıyor. Önce derliyor. Sonra QEMU'da çalıştırıp çıktıyı
> kontrol ediyor — banner basıldı mı, platform değerleri doğru mu, kesme
> tetiklendi mi, zamanlama beklenen aralıkta mı. En sonunda debugger'ı
> bağlayıp az önce elle yaptığım şeyleri otomatik doğruluyor: kesme vektörü
> kurulmuş mu, `mcause` doğru mu, değişken yazılabiliyor mu.
>
> On kontrol ve çıkış kodu döndürüyor. Yani ileride otomatik derleme sistemine
> bağlanabilir: her değişiklikten sonra ortamın bozulup bozulmadığını insan
> gözüyle değil, test ile anlıyoruz.
>
> Bir şeyi de söylemeliyim: bu testin bir faydasını zaten gördüm. Geliştirme
> sırasında, platform değiştirince derleme sisteminin objeleri yenilemediği
> bir hata vardı — yani RTG4 hedefi derlendiğini söylüyor ama aslında eski
> QEMU ikilisini bırakıyordu. Bu sessiz hatayı test yakaladı."

---

## SAHNE 11 — İsteğe bağlı: hatayı canlı göstermek (+2 dk)

**Videoya çok şey katar ama hazırlık ister.** İki seçenek var; **birini** seç.

### Seçenek A — "O satırı silersek ne olur" (kesmenin periyodikliği)

**[YAP]** `main.c` satır 87'deki `timer_schedule_next();` satırını yorum yap:
```c
            /* timer_schedule_next(); */
```

**[YAZ]** `mingw32-make && mingw32-make run`

**[EKRAN]** Banner basılır, `Zamanlayici kesmesi aktif...` yazar ve **sayaç
hiç ilerlemez** — tek bir tick satırı bile gelmez.

**[SÖYLE]**

> "Tek satır sildim ve sistem sustu. Çünkü RISC-V zamanlayıcısı tek
> seferliktir: ilk kesme oldu, ama kimse bir sonrakini kurmadığı için bir
> daha hiç olmadı. İşlemci şu an `wfi`'de sonsuza kadar uyuyor.
>
> Gömülü sistemlerde hatalar tam böyle görünür: çökme yok, hata mesajı yok,
> sadece sessizlik. Bu ortamın değeri de burada — bu hatayı kart beklemeden,
> saniyeler içinde görüp düzeltebiliyorsun."

**[YAP]** Satırı geri aç, derle, çalıştığını göster.

> **Hazırlık:** Sürüm kontrolü olmadığı için satırı geri almayı unutursan
> sorun olur. Çekimden önce `main.c`'nin bir kopyasını
> `main.c.yedek` olarak al, sahne sonunda geri koy.

### Seçenek B — Exception yakalamak (hata işleyicisi)

**[YAP]** `main.c`'deki ana döngünün başına geçersiz bir komut koy:
```c
    __asm__ volatile (".word 0x00000000");   /* gecersiz komut */
```

**[YAZ]** `mingw32-make && mingw32-make run`

**[EKRAN]**
```
*** EXCEPTION ***
  mcause = 0x00000002
  mepc   = 0x800003xx
  mtval  = 0x00000000
Sistem durduruldu.
```

**[SÖYLE]**

> "Kasıtlı olarak geçersiz bir komut koydum. İşlemci bunu yakaladı ve aynı
> kesme mekanizması üzerinden hata işleyicimize atladı. `mcause` 2 — 'geçersiz
> komut'. En üst bit sıfır, yani bu bir kesme değil gerçek bir hata.
>
> Önemli olan şu: hata sessizce yutulmuyor, nerede olduğu `mepc` ile
> adresiyle birlikte söyleniyor. Gerçek bir projede buraya breakpoint
> koymak hata avının en hızlı yolu."

**[YAP]** Satırı sil, derle.

> **Hangisini seçmeli?** Seçenek A öğretici açıdan daha güçlü (kesme
> mantığını anlatıyor), Seçenek B görsel açıdan daha etkileyici (ekranda
> büyük bir EXCEPTION yazısı). Vaktin varsa A, etki istiyorsan B.

---

## SAHNE 12 — Sınırlar ve yol haritası (20:15 – 21:45)

**Bu sahneyi atlama.** Sınırları kendin söylemek, sonradan başkasının
bulmasından çok daha iyidir.

### 12.1 Ne yapar / ne yapmaz

| Bu ortam **doğrular** | Bu ortam **doğrulamaz** |
|---|---|
| Uygulama mantığı, durum makineleri | Gerçek çevre birimlerin davranışı |
| Kesme ve zamanlayıcı mantığı | Saat / ısı / radyasyon etkileri |
| Zaman hesapları, protokol kodlama | Komut başına gerçek cycle süresi |
| Regresyon: "çalışan bir şey bozuldu mu" | FPGA içi zamanlama |

**[SÖYLE]**

> "Komut kümesi ve kesme mimarisi tarafında taviz yok, birebir aynı. Taviz
> verdiğimiz yer çevre birimler: ekranda gördüğünüz seri port QEMU'nun
> standart portu, gerçek karttaki port değil.
>
> Yani bu ortam yazılım mantığını doğrular, donanım davranışını doğrulamaz.
> Gömülü projelerde hataların büyük bölümü ilk gruptadır — durum makineleri,
> zaman hesapları, kesme içinde veri paylaşımı. Hepsi burada, kart beklemeden
> test edilebiliyor."

### 12.2 Yol haritası

> "Dört aşamalı düşünüyorum:
>
> **Birinci aşama bitti** — bu gördüğünüz ortam.
>
> **İkinci aşama:** `platform.h`'deki RTG4 adreslerini gerçek donanım
> tasarımından doğrulamak. Kart gelmeden yapılabilir, tek ihtiyaç beş sayı:
> bellek tabanı, zamanlayıcı adresi, seri port adresi ve iki saat frekansı.
>
> **Üçüncü aşama:** kart gelince JTAG üzerinden gerçek donanımda çalıştırmak.
> Kaynak kod ve derleme sistemi değişmiyor, sadece debug sunucusu değişiyor.
>
> **Dördüncü aşama, opsiyonel:** çevre birim davranışı da simüle edilmek
> istenirse QEMU'ya kendi cihaz modellerimizi yazmak. Haftalar mertebesinde
> bir iş ve ancak çevre birim yazılımı kritikse değer."

---

## SAHNE 13 — Kapanış (21:45 – 22:30)

**[SÖYLE]**

> "Özetleyelim. İstenen beş madde vardı: QEMU'da simülasyon ortamı, VSCode'da
> yazılıp çalışan kod, Hello World, debug, interrupt zamanlayıcısı. Hepsi
> çalışıyor ve hepsini canlı gösterdim.
>
> Üstüne iki şey ekledim: ortam başka bir bilgisayarda tek komutla kuruluyor,
> ve her değişiklikten sonra kendini test ediyor.
>
> En önemlisi de şu: uygulama kodunda hiçbir yerde çıplak donanım adresi yok.
> Kart geldiğinde yapılacak iş kodu yeniden yazmak değil, bir parametre
> değiştirmek ve o beş sayıyı doğrulamak.
>
> Dokümantasyon da hazır — ortamın nasıl taşındığı, ileride daha karmaşık bir
> C projesinin nasıl konulacağı yazılı durumda. Sorularınızı bekliyorum."

**[EKRAN]** Son kare: dosya ağacı veya banner çıktısı dursun.

---

# §K — Kısa sürüm (8 dakika)

Vaktin kısıtlıysa veya ikinci bir "yönetici özeti" videosu çekeceksen:

| Dk | Sahne | Not |
|---|---|---|
| 0:00–0:30 | Sahne 1 | Görev neydi |
| 0:30–1:30 | Sahne 2.3 + 2.4 | Sadece "hangi katman aynı" tablosu ve merkezî karar |
| 1:30–2:00 | Sahne 3.1 | **Sadece `platform.h`** — diğer dosyaları atla |
| 2:00–3:00 | Sahne 5 + 6 | Derle ve çalıştır |
| 3:00–4:30 | Sahne 7.1 + 7.3 | F5, `mtvec` doğrulaması |
| 4:30–6:00 | Sahne 8.1–8.3 | Kesmeyi yakala, `mcause`, çağrı yığını |
| 6:00–6:45 | Sahne 9 | Platform anahtarı |
| 6:45–7:15 | Sahne 10 | Smoke test 10/10 |
| 7:15–8:00 | Sahne 12.1 + 13 | Sınırlar ve kapanış |

**Atlanacaklar:** dosya turunun geri kalanı, VSCode dosyalarının detayı,
`firmware.lst`, CLINT register okuma, hata gösterimi sahnesi.

---

# §T — Çekim sırasında işine yarayacak notlar

## T.1 Komut kopya kâğıdı

```powershell
mingw32-make                              # derle
mingw32-make run                          # calistir  (cikis: Ctrl+A sonra X)
mingw32-make clean                        # temizle
mingw32-make PLATFORM=PLATFORM_RTG4_MIV   # RTG4 hedefi
mingw32-make info                         # ayarlari goster
tools\qemu-stop.ps1                       # arkada kalan QEMU'yu kapat

powershell -ExecutionPolicy Bypass -File tools\smoke-test.ps1
```

VSCode: **Ctrl+Shift+B** derle · **F5** debug · **F10** adımla ·
**F11** içine gir · **Shift+F5** debug'ı bitir

Debug Console (başına `-exec` şart):
```
-exec p/x $mtvec
-exec p/x $mcause
-exec p/x &trap_entry
-exec p g_tick_count
-exec set var g_tick_count = 4242
-exec x/2x 0x0200bff8
```

## T.2 Breakpoint satırları (`main.c`, mevcut hâl)

| Satır | İçerik | Ne için |
|---|---|---|
| **79** | `uint32_t mcause = csr_read(mcause);` | **Kesme işleyicisi** — Sahne 8'in ana breakpoint'i |
| **87** | `timer_schedule_next();` | Periyodikliği sağlayan satır (Sahne 11-A) |
| **118** | `uart_puts(" Hello, World!\n");` | Canlı değişiklik için güvenli nokta |
| **132** | `uint32_t reported = 0;` | `main` başı — Sahne 7'nin breakpoint'i |
| **146** | `__asm__ volatile ("wfi");` | Ana döngü, `wfi`'yi anlatırken |

## T.3 Canlı demoda patlayabilecekler

| Belirti | Çözüm | Kameradayken ne dersin |
|---|---|---|
| `riscv-none-elf-gcc: command not found` | VSCode'u yeniden başlat | "Araç yolları yeni eklendi, terminalin tazelenmesi gerekiyor." |
| F5 → "Unable to start debugging" | `tools\setup.ps1 -SkipInstall` | Demoyu terminalden `mingw32-make debug` + `mingw32-make gdb` ile kurtar |
| QEMU penceresi açılıp kapanıyor | `tools\qemu-stop.ps1`, sonra tekrar F5 | — |
| QEMU'dan çıkamıyorsun | **Ctrl+A**, bırak, **X** | Bunu zaten anlatıyorsun, sorun değil |
| GDB'de `could not convert 'main' from the host encoding` uyarısı | **Hiçbir şey** — zararsız, bilinen bir durum | Sorulursa: "GDB'nin Windows'ta bilinen bir kodlama uyarısı, debug'ı etkilemiyor." |
| Breakpoint tetiklenmiyor | Kodun gerçekten derlendiğinden emin ol (Ctrl+Shift+B) | — |
| Makefile `missing separator` | Girintiye boşluk kaçmış | **Kamerada Makefile'ı düzenlemeye kalkışma**, sahneyi kes |

## T.4 Söylerken dikkat edeceğin ifadeler

| ❌ Deme | ✅ De |
|---|---|
| "RTG4'ü simüle ediyoruz" | "RTG4 üzerinde koşacak RISC-V çekirdeğini hedefliyoruz" |
| "Kart gelince kod doğrudan çalışır" | "Kod derlenir, mantık aynı kalır; adreslerin doğrulanması gerekir" |
| "Gerçek kartta test ettim" | "Gerçek kart hedefi için **derlendiğini** doğruladım" |
| "Zamanlama birebir doğru" | "Zaman **mantığı** doğru; cycle seviyesinde donanım zamanlaması değil" |
| "Ekip tüm firmware'i burada test edebilir" | "Uygulama mantığını burada test edebilir; çevre birim sürücüleri kartta doğrulanmalı" |

## T.5 Çekim sonrası kontrol

- [ ] Sahne 11'i çektiysen **`main.c` eski hâline döndü mü?**
      (`timer_schedule_next();` açık, geçersiz komut satırı silinmiş)
- [ ] Sahne 9'u çektiysen son derleme **QEMU hedefinde mi?**
      (`mingw32-make clean && mingw32-make`)
- [ ] Son bir kez: `smoke-test.ps1` → **10/10**
- [ ] Videoda `SUNUM.md` Bölüm B kadraja girdi mi? Girdiyse o kısmı kes.
- [ ] Sahne 5'te değiştirdiğin banner yazısını kalıcı tutmak istiyor musun,
      yoksa geri alacak mısın?
