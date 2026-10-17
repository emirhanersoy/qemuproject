# Bu proje ne? — Hiç bilmeyen biri için açıklama

> Bu belge, `qemuproject` klasöründe ne yaptığımızı **gömülü sistemler hakkında hiçbir
> şey bilmeyen** birinin anlayabileceği şekilde anlatır. Teknik terimler ilk geçtikleri
> yerde açıklanır. Daha teknik ayrıntılar için `README.md`'ye bakabilirsiniz.

---

## İçindekiler

1. [Tek cümlelik özet](#1-tek-cümlelik-özet)
2. [Önce temel kavramlar](#2-önce-temel-kavramlar)
3. [Projenin amacı](#3-projenin-amacı)
4. [Neden gerekli?](#4-neden-gerekli)
5. [Neler kullandık?](#5-neler-kullandık)
6. [Nasıl çalışıyor?](#6-nasıl-çalışıyor)
7. [Örnekte tam olarak ne yaptık? (ekrandaki çıktının satır satır açıklaması)](#7-örnekte-tam-olarak-ne-yaptık)
8. [Bu ortamın yapabildikleri ve yapamadıkları](#8-bu-ortamın-yapabildikleri-ve-yapamadıkları)
9. [İlerleyen zamanlarda ne yapabiliriz?](#9-ilerleyen-zamanlarda-ne-yapabiliriz)
10. [Küçük sözlük](#10-küçük-sözlük)

---

## 1. Tek cümlelik özet

Henüz elimizde olmayan bir uzay donanımı için yazılım geliştirebilmek amacıyla,
o donanımın işlemcisini bilgisayarımızda **taklit eden** bir ortam kurduk ve bu ortamda
çalışan, saati tutan küçük bir örnek program yazdık.

---

## 2. Önce temel kavramlar

Projeyi anlamak için beş kavramı bilmek yeterli.

### 2.1 Gömülü yazılım (embedded software) nedir?

Bilgisayarınızdaki programlar (Chrome, Word) bir **işletim sisteminin** (Windows)
üzerinde çalışır. Windows onlara ekranı, dosyaları, belleği hazır verir.

**Gömülü yazılım** ise bir cihazın içindeki küçük işlemcide, çoğu zaman **hiçbir işletim
sistemi olmadan** çalışan yazılımdır. Çamaşır makinesi, araba fren kontrolcüsü, uydu
— hepsinin içinde böyle yazılımlar var. Burada yazılımcı her şeyi kendisi yapmak
zorundadır: işlemciyi açılışta hazırlamak, belleği düzenlemek, donanımla doğrudan
konuşmak.

> **Benzetme:** Normal yazılım, eşyalı bir otele yerleşmek gibidir — yatak, havlu,
> resepsiyon hazırdır. Gömülü yazılım ise boş bir arsaya ev kurmak gibidir: önce
> temeli siz atarsınız.

Bizim projede de işletim sistemi yok. Kod doğrudan işlemcinin üzerinde koşuyor.
Buna **bare-metal** ("çıplak metal") denir.

### 2.2 FPGA nedir? RTG4 nedir?

Normal bir işlemci (bilgisayarınızdaki Intel/AMD gibi) fabrikada üretilirken
devreleri **kalıcı olarak** çizilmiş bir çiptir. Değiştirilemez.

**FPGA** ise içi **boş ve programlanabilir** bir çiptir. İçinde binlerce küçük
mantık bloğu vardır ve bunların birbirine nasıl bağlanacağını siz belirlersiniz.
Yani FPGA'ya "şimdi bir işlemci ol" diyebilirsiniz.

> **Benzetme:** Normal işlemci, kalıptan dökülmüş plastik bir oyuncaktır.
> FPGA ise bir LEGO kutusudur — aynı parçalarla araba da yapabilirsiniz, ev de.

**RTG4**, Microchip firmasının **uzay için** ürettiği bir FPGA'dır. Uzayda radyasyon
çiplerin içindeki bitleri bozabilir (bir 0'ı 1 yapabilir). RTG4 buna karşı
dayanıklı olacak şekilde tasarlanmıştır. Uydularda ve uzay araçlarında kullanılır.

**Önemli nokta: RTG4'ün içinde hazır bir işlemci yoktur.** O bir LEGO kutusudur.

### 2.3 Soft-core nedir? Mi-V nedir?

Madem RTG4'te işlemci yok, yazılımı nerede çalıştıracağız? Cevap: FPGA'nın içine
bir işlemciyi **LEGO'larla inşa ediyoruz**. Bu şekilde FPGA'nın içine kurulan
işlemcilere **soft-core** (yumuşak çekirdek) denir — "yazılımla tarif edilmiş işlemci".

Microchip, bunun için hazır bir tarif veriyor: **Mi-V** (örneğin `MIV_RV32`).
Mühendisler Libero SoC adlı bir programla bu tarifi RTG4'ün içine yerleştirir.

Yani ekipte konuşulan "RTG4 RISC-V işlemcisi" aslında şu demektir:
**RTG4 FPGA'sının içine yerleştirilmiş Mi-V işlemcisi.**

### 2.4 RISC-V nedir?

Her işlemcinin bir "dili" vardır; hangi komutları anladığını belirleyen bir
kurallar kitabıdır. Buna **komut seti mimarisi (ISA)** denir. Bilgisayarınızdaki
işlemci "x86" dilini konuşur, telefonunuzdaki "ARM" dilini.

**RISC-V**, herkesin ücretsiz kullanabildiği açık bir işlemci dilidir. Mi-V bu dili
konuşur. Bizim kullandığımız sürüm **RV32IMAC**:

| Harf | Anlamı |
|---|---|
| RV32 | 32 bitlik RISC-V |
| I | Temel tamsayı komutları (toplama, karşılaştırma, atlama...) |
| M | Çarpma ve bölme komutları |
| A | Atomik komutlar (birden fazla işin aynı veriye çakışmadan erişmesi için) |
| C | Sıkıştırılmış (kısa) komutlar — kod daha az yer kaplar |

**Bu çok önemli:** Bir program bir işlemcinin dilini konuşuyorsa, aynı dili konuşan
başka bir işlemcide de çalışır. Bizim yaklaşımımız bu gerçeğe dayanıyor.

### 2.5 Simülatör / emülatör nedir? QEMU nedir?

**Emülatör**, bir donanımı yazılımla taklit eden programdır. Bilgisayarınızda
eski bir oyun konsolunun oyununu çalıştıran programlar emülatördür: konsol yoktur,
ama program onu taklit eder.

**QEMU**, en yaygın açık kaynaklı emülatördür. Birçok işlemciyi taklit edebilir,
RISC-V dahil. Biz QEMU'ya "bir RISC-V işlemcisi ol" diyoruz ve yazdığımız programı
onun üzerinde çalıştırıyoruz.

---

## 3. Projenin amacı

Ekip, RTG4 kartı üzerinde çalışacak yazılımlar geliştirecek. Ama:

- **Fiziksel kart henüz gelmedi.**
- Kart gelene kadar yazılımcıların boş beklemesi istenmiyor.

Bu yüzden amaç şu:

> **Kart olmadan, kartın işlemcisi için yazılım yazabileceğimiz, çalıştırabileceğimiz
> ve hatalarını ayıklayabileceğimiz bir ortam kurmak.**

Bu tür ortamlara **SiL (Software-in-the-Loop)** denir: "döngüdeki yazılım" —
yani gerçek donanım yerine yazılımın kendisinin simüle edilmiş bir ortamda
test edildiği düzen.

Müdürün ek olarak istedikleri:

1. **Debug (hata ayıklama) araçları** — programı satır satır durdurup içine bakabilmek.
2. **Timer interrupt (zamanlayıcı kesmesi) örneği** — işlemcinin "zamanı tutabildiğini"
   gösteren bir program.

Üçü de yapıldı ve çalışıyor.

---

## 4. Neden gerekli?

### 4.1 Kart gelene kadar beklemek pahalı

Gömülü projelerde donanım genellikle yazılımdan **geç** gelir. Yazılımcılar donanımı
beklerse, kart geldiğinde her şeye sıfırdan başlanır ve proje gecikir. SiL ortamı
sayesinde kart geldiğinde yazılımın büyük kısmı **zaten yazılmış ve test edilmiş**
olur.

### 4.2 Gerçek donanımda hata ayıklamak zor ve riskli

- Uzay kartları **pahalı** ve **az sayıdadır**. Her yazılımcıya bir tane verilemez.
- Gerçek kartta program çöktüğünde ne olduğunu görmek zordur.
- QEMU'da ise programı istediğiniz an durdurabilir, tüm değişkenlere bakabilir,
  binlerce kez saniyeler içinde yeniden başlatabilirsiniz.

### 4.3 Otomatik test yapılabilir

Bilgisayarda çalışan bir ortam, her kod değişikliğinden sonra **otomatik olarak**
test edilebilir. Bunu `tools/smoke-test.ps1` betiğiyle yapıyoruz (bkz. §6.6).

### 4.4 Neden Simics değil de QEMU?

Ekibin ilk tercihi **Intel Simics** idi. Simics, çevre birimlerini (UART, zamanlayıcı
gibi) çok ayrıntılı taklit edebilen profesyonel bir simülatördür. Ancak **lisansı
alınamadı**. Bu yüzden ücretsiz ve açık kaynaklı **QEMU** seçildi.

Bunun bir bedeli var ve saklamıyoruz: QEMU'da RTG4 veya Mi-V'nin hazır bir modeli
**yok**. Bunu nasıl çözdüğümüzü bir sonraki bölümde anlatıyoruz.

---

## 5. Neler kullandık?

### 5.1 Ana fikir: "Aynı dili konuşan yakın akraba"

QEMU, RTG4'ü tanımıyor. Ama QEMU'da **`virt`** adlı genel amaçlı bir RISC-V makinesi
var. Bu makine ile Mi-V'yi karşılaştırdığımızda:

| Özellik | Gerçek RTG4 / Mi-V | QEMU `virt` | Aynı mı? |
|---|---|---|---|
| İşlemci dili (ISA) | RV32IMAC | RV32IMAC | **Birebir aynı** |
| Kesme sistemi | RISC-V standardı | RISC-V standardı | **Birebir aynı** |
| Zamanlayıcı | CLINT | CLINT | **Çalışma mantığı aynı**, adresi farklı |
| Zamanlayıcının adresi | `0x4400_0000` | `0x0200_0000` | Farklı |
| Seri port (UART) | CoreUARTapb | NS16550A | Farklı model |
| Bellek başlangıcı | `0x8000_0000` | `0x8000_0000` | Aynı |

Yani **işlemcinin kendisi** birebir aynı davranıyor. Farklı olan, işlemcinin etrafındaki
çevre birimlerin **adresleri** ve **modelleri**.

> **Benzetme:** Aynı model iki arabayı düşünün. Motor, vites, direksiyon aynı. Sadece
> birinde radyo torpidoda, diğerinde ortada. Sürücüye "radyo şurada" diye bir not
> verirseniz, aynı sürücü iki arabayı da kullanır.

Bizim "not"umuz `platform.h` dosyası.

### 5.2 Merkezî tasarım kararı: `platform.h`

Gömülü yazılımda donanımla **adresler** üzerinden konuşulur. Örneğin "seri porta bir
harf göndermek" demek, "`0x10000000` adresine o harfin kodunu yazmak" demektir.

Programın her yerine bu sayıları dağıtırsak, kart geldiğinde yüzlerce yeri
değiştirmemiz gerekir. Bunun yerine **tüm adresleri tek bir dosyada, isim vererek**
topladık:

```c
// QEMU için
#define CLINT_BASE   0x02000000   // zamanlayıcının adresi
#define UART_BASE    0x10000000   // seri portun adresi

// Gerçek RTG4 için
#define CLINT_BASE   0x44000000
#define UART_BASE    0x70001000
```

Program her zaman `CLINT_BASE` **ismini** kullanıyor, sayıyı değil. Hedef değiştirmek
tek bir komut:

```powershell
mingw32-make                              # QEMU için derle (varsayılan)
mingw32-make PLATFORM=PLATFORM_RTG4_MIV   # gerçek RTG4 için derle
```

Uygulama kodunun (`main.c`) **tek satırı bile değişmiyor.**

> **Dürüst not:** RTG4 tarafındaki adresler, Mi-V referans tasarımlarındaki
> **tipik değerlerdir**. RTG4 bir FPGA olduğu için bu adresleri tasarımı yapan
> mühendis belirler. Gerçek değerler Libero SoC'un "memory map" raporundan
> doğrulanmalıdır (bkz. §9, Faz 2).

### 5.3 Kullanılan araçlar

| Araç | Ne işe yarar | Benzetme |
|---|---|---|
| **riscv-none-elf-gcc** (sürüm 15.2) | C kodunu RISC-V işlemcisinin anlayacağı makine koduna çevirir. Buna **çapraz derleyici (cross compiler)** denir, çünkü Windows'ta çalışıp **başka bir işlemci** için kod üretir. | Türkçe yazılmış bir kitabı Japoncaya çeviren tercüman |
| **riscv-none-elf-gdb** (sürüm 16.3) | **Debugger** (hata ayıklayıcı). Çalışan programı durdurur, değişkenlerine bakar, satır satır ilerletir. | Filmi duraklatıp kare kare izlemek |
| **QEMU** (sürüm 11.1) | RISC-V işlemcisini taklit eden emülatör. Derlenmiş programımızı çalıştırır. | Kart yerine geçen sanal kart |
| **mingw32-make** | Derleme adımlarını otomatik yapar. Hangi dosyanın değiştiğine bakıp sadece gerekenleri yeniden derler. | Yemek tarifini adım adım uygulayan aşçı |
| **VSCode** + C/C++ eklentisi | Kodu yazdığımız, tek tuşla derleyip debug ettiğimiz editör. | Atölye tezgâhı |
| **PowerShell betikleri** (`tools/`) | Kurulumu, QEMU'yu başlatmayı ve otomatik testi yapar. | Yardımcı eleman |

Hepsi ücretsiz ve açık kaynaklı. Kurulum için yönetici yetkisi gerekmedi.
`tools/setup.ps1` hepsini yeni bir bilgisayara tek komutla kurar.

### 5.4 Proje dosyaları

| Dosya | Görevi |
|---|---|
| `startup.S` | İşlemci açıldığında **ilk çalışan kod**. Ortamı hazırlayıp `main`'e geçer. Ayrıca kesme geldiğinde işlemcinin atladığı giriş noktası (`trap_entry`) burada. Assembly (işlemcinin kendi dili) ile yazılı. |
| `main.c` | Asıl program: ekrana yazı yazar, zamanlayıcıyı kurar, kesmeleri işler. C dilinde. |
| `uart.c` / `uart.h` | Seri porta (UART) yazı göndermeyi sağlayan **sürücü**. Hem QEMU'nun hem RTG4'ün seri portunu destekler. |
| `platform.h` | ★ Tüm donanım adresleri. QEMU ↔ RTG4 anahtarı burada. |
| `riscv_csr.h` | İşlemcinin özel kontrol register'larına (CSR) erişim için kısayollar. |
| `linker.ld` | Programın bellekte **nereye** yerleşeceğini anlatan harita. |
| `Makefile` | Derleme tarifi. |
| `.vscode/` | VSCode ayarları: `Ctrl+Shift+B` ile derleme, `F5` ile debug. |
| `tools/` | Kurulum, QEMU başlatma/durdurma ve otomatik test betikleri. |

---

## 6. Nasıl çalışıyor?

### 6.1 Büyük resim

```
  ┌──────────────┐    derleyici     ┌───────────────┐     QEMU      ┌──────────────┐
  │  C ve        │  (gcc + linker)  │ firmware.elf  │   yükler ve   │ Sanal RISC-V │
  │  assembly    │ ───────────────► │ (makine kodu) │ ────────────► │   işlemci    │
  │  kaynak kod  │                  │               │   çalıştırır  │              │
  └──────────────┘                  └───────────────┘               └──────┬───────┘
                                                                           │ seri port
                                                                           ▼
                                                                    VSCode terminali
                                                                    "Hello, World!"
                                                                    "[tick 10] ..."
         ┌──────────────┐  bağlanır (port 1234)                            ▲
         │     GDB      │ ─────────────────────────────────────────────────┘
         │  (debugger)  │  durdur, adım at, değişkene bak
         └──────────────┘
```

### 6.2 Adım 1 — Derleme: koddan makine koduna

`Ctrl+Shift+B`'ye bastığınızda:

1. **Derleyici** her `.c` ve `.S` dosyasını ayrı ayrı makine koduna çevirir
   (`main.o`, `uart.o`, `startup.o`).
2. **Linker** (bağlayıcı) bu parçaları birleştirir ve `linker.ld` haritasına göre
   her parçayı bellekte doğru adrese yerleştirir. Örneğin "açılış kodu tam
   `0x80000000` adresinde olsun" kuralı buradan gelir.
3. Sonuçta şu dosyalar oluşur:

| Dosya | Ne işe yarar |
|---|---|
| `firmware.elf` | Asıl program + debug bilgileri. QEMU ve GDB bunu kullanır. |
| `firmware.bin` | Sadece ham makine kodu. |
| `firmware.hex` | Çipe yüklemek için kullanılan standart format. Kart gelince işe yarayacak. |
| `firmware.map` | Hangi fonksiyonun hangi adreste olduğunu gösteren rapor. |
| `firmware.lst` | Her C satırının hangi makine komutlarına dönüştüğünü gösteren liste. Öğrenmek için çok faydalı. |

Program toplamda yaklaşık **22 KB** yer kaplıyor (bunun ~20 KB'ı yığın ve heap için
ayrılmış boş alan). 8 MB'lık belleğin %0.27'si.

### 6.3 Adım 2 — Açılış: işlemci uyandığında ne olur?

İşlemci açıldığında **hiçbir şey hazır değildir**. C dili, çalışabilmek için bazı
şeylerin önceden hazırlanmış olmasını bekler. Bunu `startup.S` yapar. Bu dosya
**assembly** ile yazılmak zorundadır, çünkü henüz C'nin çalışabileceği bir ortam yoktur.

Sırayla:

| # | Ne yapılıyor | Neden |
|---|---|---|
| 0 | QEMU önce `0x1000` adresinde kendi küçük açılış kodunu çalıştırır, sonra bizim kodumuza (`0x80000000`) atlar. | Gerçek işlemcilerdeki "reset vektörü" davranışının taklidi. |
| 1 | Kesmeler kapatılır. | Ortam hazır değilken bir kesme gelirse sistem çöker. |
| 2 | `gp` (global pointer) ayarlanır. | Derleyici global değişkenlere hızlı erişmek için bunu kullanır. |
| 3 | `sp` (stack pointer) ayarlanır. | C fonksiyonlarının geçici verilerini koyacağı **yığın** alanı. Bu olmadan hiçbir C fonksiyonu çağrılamaz. |
| 4 | `.data` bölümü kopyalanır. | Başlangıç değeri olan değişkenler (`int x = 5;`) kalıcı bellekten RAM'e taşınır. QEMU'da gerek yok, ama gerçek RTG4'te şart. Aynı kod iki durumda da doğru çalışır. |
| 5 | `.bss` bölümü sıfırlanır. | C dili, başlangıç değeri verilmemiş global değişkenlerin **0** olmasını garanti eder. Bunu biz sağlamalıyız. |
| 6 | `mtvec` = `trap_entry` yapılır. | İşlemciye "bir kesme gelirse **buraya** atla" denir. |
| 7 | `main()` çağrılır. | Artık C dünyasındayız. |

> **Benzetme:** Bir tiyatro oyunundan önce sahne ekibi ışıkları kurar, dekoru
> yerleştirir, perdeyi hazırlar. Oyuncular (`main`) ancak ondan sonra sahneye çıkar.
> `startup.S` sahne ekibidir.

### 6.4 Adım 3 — Program: `main()` ne yapıyor?

```c
int main(void)
{
    uart_init();        // 1) Seri portu hazırla
    print_banner();     // 2) "Hello, World!" ve platform bilgilerini yaz
    timer_start();      // 3) Zamanlayıcıyı kur ve kesmeleri aç

    for (;;) {          // 4) Sonsuza kadar:
        wfi;            //    - kesme gelene kadar uyu
                        //    - her 10 tick'te (1 saniye) bir rapor yaz
    }
}
```

**`for (;;)` neden sonsuz döngü?** Gömülü bir cihazın "kapanıp masaüstüne dönmesi"
diye bir şey yoktur. Çamaşır makinesinin yazılımı fişten çekilene kadar çalışır.
`main` asla bitmez.

**`wfi` nedir?** "Wait For Interrupt" — "kesme gelene kadar bekle". İşlemciyi uyutur.
Boş bir döngüde sürekli dönmek yerine bunu kullanmak gerçek donanımda **enerji
tasarrufu** sağlar — uzayda enerji çok değerlidir.

### 6.5 Adım 4 — Zamanlayıcı kesmesi: projenin kalbi

Bu, müdürün özellikle istediği kısım ve gömülü sistemlerin en temel kavramlarından biri.

#### Kesme (interrupt) nedir?

İşlemci bir şey yaparken, donanımın "**dur, önce bana bak!**" demesidir.

> **Benzetme:** Kitap okurken kapı zili çalıyor. Okuduğunuz sayfayı işaretlersiniz,
> kapıya bakarsınız, sonra **tam kaldığınız yerden** okumaya devam edersiniz.
> Kapı zili = kesme. Sayfayı işaretlemek = register'ları kaydetmek.
> Kaldığınız yerden devam etmek = `mret` komutu.

Kesme olmasaydı, işlemcinin sürekli "zil çaldı mı? zil çaldı mı?" diye kontrol etmesi
gerekirdi (buna **polling** denir). Bu hem enerji israfıdır hem de işlemci başka iş
yapamaz.

#### Zamanlayıcı (CLINT) nasıl çalışır?

İşlemcinin yanında **CLINT** adlı küçük bir zamanlayıcı birimi var. İçinde iki sayı bulunur:

- **`mtime`** — durmadan artan bir sayaç. QEMU'da saniyede **10 milyon** kez artar.
  Bir saatin saniye ibresi gibidir, sadece çok daha hızlıdır.
- **`mtimecmp`** — bizim koyduğumuz bir hedef sayı. Çalar saatin alarm ayarı gibidir.

**`mtime`, `mtimecmp`'ye ulaştığı anda donanım kesme üretir.**

Biz her 100 milisaniyede bir kesme istiyoruz:

```
  saniyede 10.000.000 artış  ÷  saniyede 10 kesme  =  her kesme arası 1.000.000 artış
```

#### Bir kesme anında olanlar (saniyede 10 kez)

```
 main() içinde wfi ile uyuyor
          │
          │   mtime, mtimecmp'ye ulaştı → DONANIM KESMESİ
          ▼
 ┌─────────────────────────────────────────────────────────────────┐
 │ İşlemci otomatik olarak:                                        │
 │   - nerede kaldığını mepc'ye yazar  (sayfayı işaretler)         │
 │   - kesmenin sebebini mcause'a yazar (0x80000007 = zamanlayıcı) │
 │   - yeni kesmeleri geçici olarak kapatır                        │
 │   - mtvec'teki adrese, yani trap_entry'ye atlar                 │
 └─────────────────────────────────────────────────────────────────┘
          │
          ▼
 trap_entry  (startup.S, assembly)
   - O an kullanılan 16 register'ı yığına kaydeder
   - trap_handler() C fonksiyonunu çağırır
          │
          ▼
 trap_handler()  (main.c, C)
   - mcause'a bakar: "zamanlayıcı kesmesi mi?" → evet
   - g_tick_count'u 1 artırır
   - SONRAKİ alarmı kurar: mtimecmp = şimdiki mtime + 1.000.000
          │
          ▼
 trap_entry  (geri dönüş)
   - 16 register'ı yığından geri yükler
   - mret komutu: kesmeleri geri açar ve tam kaldığı yere döner
          │
          ▼
 main() uyandı → tick sayısı 10'un katı mı? → evetse "[tick N] uptime = N/10 s" yaz
```

#### Neden bu kısımlar önemli?

- **Neden `trap_entry` assembly?** Kesme, bir C fonksiyonunun **tam ortasında**
  aniden gelir. O anki register'ları kaydetmek ve kesmeden normal `ret` ile değil
  özel **`mret`** komutuyla dönmek C ile yapılamaz. `mret` kullanılmasaydı kesmeler
  bir daha hiç açılmazdı ve saat ilk tick'te dururdu.
- **Neden her kesmede alarmı yeniden kuruyoruz?** RISC-V zamanlayıcısı **tek
  seferliktir** — çalar saat gibi bir kez çalar ve kendini yeniden kurmaz. O satır
  silinirse kesme ya hiç tekrar gelmez ya da durmadan art arda tetiklenir.
- **Neden `volatile`?** `g_tick_count` değişkeni kesme içinde değişiyor. `volatile`
  denmezse derleyici "`main` bu değişkeni hiç değiştirmiyor" diye düşünüp değeri bir
  kez okur ve önbellekte tutar; `main` sayacın arttığını hiç görmez.

### 6.6 Adım 5 — Debug: programın içine bakmak

`F5`'e bastığınızda:

1. Proje derlenir.
2. QEMU **durdurulmuş halde** başlatılır ve 1234 numaralı ağ portunu açar
   ("debugger'ım bağlansın diye bekliyorum").
3. Betik portun gerçekten açıldığını kontrol eder.
4. GDB bu porta bağlanır. VSCode, GDB'yi arka planda kullanarak size görsel bir arayüz sunar.
5. Program `main()`'in ilk satırında durur.
6. Debug'ı durdurunca QEMU otomatik kapanır.

Bu sırada yapabildikleriniz:

- **Breakpoint** koymak (satır numarasının soluna tıklayın) — program o satıra
  gelince durur.
- **Adım adım ilerlemek** — `F10` (satırı atla), `F11` (fonksiyonun içine gir).
- **Değişkenleri izlemek** — örneğin `g_tick_count`'un arttığını canlı görmek.
- **İşlemcinin özel register'larını okumak** — `$mcause`, `$mepc` gibi.
- **Değişkenin değerini elle değiştirmek** — "sayaç 4242 olsaydı ne olurdu?" diye denemek.

Bu ortamda GDB ile doğrulanan değerler:

| Ne | Değer | Anlamı |
|---|---|---|
| `mtvec` | `0x8000007c` | Kesme adresi doğru: tam `trap_entry`'yi gösteriyor |
| `mcause` | `0x80000007` | Kesmenin sebebi: makine zamanlayıcısı (beklenen) |
| `mie` | `0x00000080` | Zamanlayıcı kesmesi açık |
| `mstatus` | `0x00001880` | Kesme içindeyken yeni kesmeler kapalı (doğru davranış) |

### 6.7 Otomatik test: `smoke-test.ps1`

Bu betik tüm zinciri **insan müdahalesi olmadan** test eder ve 10 kontrol yapar:

1. Proje derleniyor mu?
2. "Hello, World!" yazıyor mu?
3. Platform bilgileri doğru mu?
4. Zamanlayıcı kesmesi geliyor mu?
5. Zaman doğru akıyor mu? (5 saniyede 30–50 arası tick bekleniyor)
6. GDB bağlanıp `main`'de durabiliyor mu?
7. Kesme adresi doğru kurulmuş mu?
8. Kesme sebebi zamanlayıcı mı?
9. Debugger değişken değiştirebiliyor mu?
10. GDB betiği sonuna kadar çalıştı mı?

Sonuç: **10/10 geçiyor.** Herhangi bir değişiklikten sonra ilk çalıştırılması gereken
şey bu betik. Sonunda bir çıkış kodu döndürdüğü için ileride otomatik test
sistemlerine (CI) de bağlanabilir.

---

## 7. Örnekte tam olarak ne yaptık?

Gördüğünüz çıktıyı satır satır açıklayalım.

### 7.1 Betik mesajları (bizim yardımcı betiğimiz yazıyor)

```
[qemu-debug] baslatiliyor: C:\Program Files\qemu\qemu-system-riscv32.exe
[qemu-debug] GDB sunucusu : localhost:1234 (islemci durdurulmus)
[qemu-debug] hazir, GDB baglanabilir.
[qemu-debug] UART ciktisi asagida. Debug bitince QEMU kapanir.
```

Bunları **firmware değil**, `tools/qemu-debug.ps1` yazıyor. QEMU başlatıldı, sanal
işlemci durdurulmuş halde debugger'ı bekliyor, debugger bağlandı. Bu noktadan sonraki
her şey **sanal RISC-V işlemcisinin içinde çalışan bizim programımızın** çıktısı.

### 7.2 Banner (`print_banner()` fonksiyonu yazıyor)

```
===========================================
 Hello, World!
 RTG4 / Mi-V RV32 firmware - QEMU SiL
===========================================
```

Bu satırların ekrana gelmesi tek başına çok şey kanıtlıyor:

- Derleyici, RISC-V için **doğru makine kodu** üretti.
- `linker.ld` programı **doğru adrese** yerleştirdi.
- `startup.S` yığını kurup `main()`'e **başarıyla geçti**.
- UART sürücümüz seri porta **doğru şekilde** harf gönderebiliyor.

Bunların herhangi biri yanlış olsaydı ekranda hiçbir şey görmezdiniz.

> **Not:** Burada `printf` kullanmıyoruz. İşletim sistemi olmadığı için standart C
> kütüphanesini bağlamadık. Her harfi UART'a tek tek kendimiz gönderiyoruz
> (`uart_puts` fonksiyonu). Sayıları yazdırma fonksiyonlarını da (`uart_put_u32`,
> `uart_put_hex32`) kendimiz yazdık.

### 7.3 Platform bilgileri (`platform.h`'den geliyor)

```
 Platform   : QEMU riscv32 'virt' (RTG4/Mi-V vekili)
 RAM base   : 0x80000000
 CLINT base : 0x02000000
 UART base  : 0x10000000
 mtime freq : 10000000 Hz
 Tick       : 100 ms
```

| Satır | Anlamı |
|---|---|
| `Platform` | Program QEMU hedefi için derlendi. "Vekili" = RTG4'ün yerine geçen. |
| `RAM base` | Belleğin başladığı adres. Programımız burada. RTG4'te de aynı. |
| `CLINT base` | Zamanlayıcının adresi. RTG4'te `0x44000000` olacak. |
| `UART base` | Seri portun adresi. RTG4'te `0x70001000` olacak (doğrulanmalı). |
| `mtime freq` | Zamanlayıcı saniyede 10 milyon artıyor. RTG4'te kartın saat frekansına bağlı (tahminen 50 MHz). |
| `Tick` | Her 100 ms'de bir kesme istedik. |

Bu satırlar, programın **hangi donanım ayarlarıyla** derlendiğini her açılışta
gösteriyor. Yanlış hedef için derlenmiş bir programı ilk bakışta fark etmenizi sağlar.

### 7.4 Zamanlayıcı başladı

```
-------------------------------------------
Zamanlayici kesmesi aktif. Sayac ilerliyor...
```

`timer_start()` çalıştı: ilk alarm kuruldu, zamanlayıcı kesmesi açıldı, genel kesmeler
açıldı. Bu andan itibaren işlemci saniyede 10 kez kesiliyor.

### 7.5 Tick'ler — kesmenin çalıştığının kanıtı

```
[tick 10] uptime = 1 s
[tick 20] uptime = 2 s
[tick 30] uptime = 3 s
[tick 40] uptime = 4 s
[tick 50] uptime = 5 s
```

Her satır arasında işlemci **10 kez** kesildi. Arka planda olan şu:

```
 0.0 s  ─ alarm kuruldu
 0.1 s  ─ KESME → tick=1  → alarm +0.1 s
 0.2 s  ─ KESME → tick=2  → alarm +0.1 s
   ...
 1.0 s  ─ KESME → tick=10 → main uyandı, 10'un katı → "[tick 10] uptime = 1 s" yazdı
 1.1 s  ─ KESME → tick=11 → main uyandı, 10'un katı değil → yazmadan tekrar uyudu
   ...
 2.0 s  ─ KESME → tick=20 → "[tick 20] uptime = 2 s"
```

Bu çıktı şunları kanıtlıyor:

1. **Kesme sistemi çalışıyor** — `mtvec`, `trap_entry`, `trap_handler`, `mret` zinciri doğru.
2. **Kesme tekrar tekrar geliyor** — her kesmede alarmı yeniden kurmamız işe yarıyor.
3. **Zaman doğru akıyor** — ekrandaki satırlar gerçekten yaklaşık **saniyede bir** geliyor.
   Yani `mtime` frekansı ve adım hesabı doğru.
4. **Kesme ile ana program arasındaki iletişim çalışıyor** — kesme `g_tick_count`'u
   artırıyor, `main` bunu görüyor (`volatile` sayesinde).

> **Burada önemli olan şey:** Uydudaki gerçek bir yazılım da tam olarak bu temel
> üzerine kurulur. "Her 100 ms'de bir sensörü oku", "her saniye yer istasyonuna durum
> bilgisi gönder", "5 saniye cevap gelmezse yedek sisteme geç" gibi işlerin hepsi
> zamanlayıcı kesmesine dayanır. Biz o temelin çalıştığını gösterdik.

---

## 8. Bu ortamın yapabildikleri ve yapamadıkları

Bu sınırları açıkça bilmek ve söylemek önemli.

### ✅ Yapabildikleri

- **Uygulama mantığı** — algoritmalar, hesaplamalar, karar verme kodu.
- **Kesme ve zamanlayıcı mantığı** — işlemci seviyesinde birebir aynı.
- **Durum makineleri** — "şu durumdaysan ve şu olursa şuna geç" mantığı.
- **Haberleşme protokolü kodu** — mesajları paketleme, çözme, kontrol toplamı.
- **Regresyon testleri** — her değişiklikten sonra eski özelliklerin bozulmadığını
  otomatik kontrol etmek.

### ❌ Yapamadıkları

- **Gerçek çevre birim davranışı** — QEMU'nun UART'ı RTG4'ün UART'ıyla aynı model değil.
  RTG4'e özgü çevre birimler (Libero'da eklenecek özel devreler) burada yok.
- **FPGA'ya özgü gecikmeler** — gerçek donanımdaki sinyal gecikmeleri simüle edilmiyor.
- **Fiziksel etkiler** — sıcaklık, saat kayması, **radyasyon kaynaklı bit hataları**.
- **Komut komut doğru zamanlama** — QEMU işlemcinin her komutu kaç saat çevriminde
  çalıştırdığını taklit etmez. "Bu fonksiyon tam 47 mikrosaniye sürer" gibi ölçümler
  burada güvenilir değil.

> **Özetle:** Bu ortam "**yazılımın mantığı doğru mu?**" sorusunu cevaplar.
> "**Gerçek kartta tam olarak nasıl davranır?**" sorusunu ise ancak kart cevaplar.
> Amaç kartı gereksiz kılmak değil, kart geldiğinde hazır olmak.

---

## 9. İlerleyen zamanlarda ne yapabiliriz?

### Faz 1 — Bu ortam ✅ (bitti)

SiL ortamı kuruldu, örnek program çalışıyor, debug ve otomatik test hazır.

### Faz 2 — Adresleri gerçek tasarımla doğrulamak

RTG4 bir FPGA olduğu için çevre birimlerin adreslerini **tasarımı yapan mühendis**
belirler. Donanım ekibinden Libero SoC projesinin **memory map raporu** istenmeli ve
`platform.h`'deki şu değerler doğrulanmalı:

| Değer | Şu anki tahmin | Nereden doğrulanacak |
|---|---|---|
| Zamanlayıcı adresi (`CLINT_BASE`) | `0x4400_0000` | MIV_RV32 yapılandırması |
| Seri port adresi (`UART_BASE`) | `0x7000_1000` | CoreUARTapb'ın bağlandığı adres |
| Bellek adresi (`RAM_BASE`) | `0x8000_0000` | LSRAM / TCM / DDR yerleşimi |
| Zamanlayıcı frekansı | 50 MHz | Libero'daki sistem saati (`SYS_CLK`) |
| Seri port saat frekansı | 50 MHz | APB veriyolu saati |

Bu, **en az emek isteyen ama en önemli** sonraki adım. Sadece `platform.h`'de birkaç
sayı değişecek.

### Faz 3 — Gerçek kartta çalıştırmak

Kart geldiğinde:

- Program, **FlashPro** programlayıcı ve **JTAG** bağlantısı ile karta yüklenir.
- Debug için QEMU yerine **OpenOCD** kullanılır. OpenOCD, GDB ile gerçek kart
  arasında köprü kurar.
- **İyi haber:** GDB'nin bakış açısından fark yok. VSCode'daki `launch.json`'da sadece
  bağlantı adresi değişir. Kaynak kod ve derleme sistemi **aynı kalır**.
- `firmware.hex` dosyası zaten üretiliyor; kart programlama akışında kullanılabilir.

### Faz 4 (isteğe bağlı) — QEMU'ya gerçek Mi-V modeli yazmak

Çevre birimlerinin davranışı da simüle edilmek istenirse, QEMU'nun kaynak koduna
(C ile) bir `miv` makinesi ve RTG4'ün UART modeli (CoreUARTapb) eklenebilir. Bu,
Simics'in sağlayacağı doğruluğa yaklaşmanın yoludur. Ancak **haftalar süren** bir iştir
ve sadece çevre birim yazılımı kritikse değer.

### Örnek programı geliştirmek için fikirler

Yukarıdaki fazlardan bağımsız, bu ortamda hemen yapılabilecekler:

| Fikir | Ne öğretir / ne kazandırır |
|---|---|
| **Git ile sürüm kontrolü** | Değişikliklerin geçmişini tutmak, ekiple paylaşmak. `.gitignore` dosyası hazır. |
| **Harici kesme örneği (PLIC)** | Zamanlayıcı dışındaki donanımlardan (örneğin seri porttan gelen bir harf) kesme almak. Gerçek uygulamaların neredeyse hepsi bunu kullanır. |
| **Seri porttan komut almak** | Klavyeden yazılan bir komuta cevap veren küçük bir "komut satırı". Gerçek kartta test için çok kullanışlıdır. |
| **Yazılım kesmesi ve `ecall`** | Programın kendi kendine kesme üretmesi. İleride görev zamanlayıcı/RTOS yazmanın temeli. |
| **Watchdog (bekçi köpeği) mantığı** | Program kilitlenirse sistemi otomatik yeniden başlatma. Uzay yazılımlarında zorunludur. |
| **Birim test iskeleti** | Kodun bir kısmını doğrudan Windows'ta derleyip test etmek. Çok daha hızlı test döngüsü. |
| **Optimize "release" derlemesi (`-O2`)** | Şu an debug kolaylığı için optimizasyon kapalı. Uçacak yazılım optimize derlenir. |
| **Otomatik test sunucusu (CI)** | Her kod değişikliğinde `smoke-test.ps1`'in otomatik çalışması. Betik zaten buna hazır. |
| **Bir RTOS denemek** (FreeRTOS gibi) | Birden fazla görevi "aynı anda" çalıştırmak. Zamanlayıcı kesmesi RTOS'ların kalbidir; bu örnek onun ilk adımı. |

---

## 10. Küçük sözlük

| Terim | Basit anlamı |
|---|---|
| **Bare-metal** | İşletim sistemi olmadan, doğrudan donanım üzerinde çalışan yazılım. |
| **FPGA** | İçindeki devreleri sonradan programlanabilen çip ("LEGO kutusu"). |
| **RTG4** | Microchip'in uzay için radyasyona dayanıklı FPGA'sı. |
| **Soft-core** | FPGA'nın içine yerleştirilen işlemci. |
| **Mi-V** | Microchip'in RISC-V soft-core işlemci ailesi. |
| **RISC-V** | Açık ve ücretsiz bir işlemci komut dili. |
| **ISA** | İşlemcinin anladığı komutların listesi, yani işlemcinin "dili". |
| **QEMU** | İşlemcileri yazılımla taklit eden emülatör. |
| **SiL** | Software-in-the-Loop: yazılımı gerçek donanım yerine simüle edilmiş ortamda test etmek. |
| **Çapraz derleyici** | Bir bilgisayarda çalışıp başka tür bir işlemci için kod üreten derleyici. |
| **Linker / linker script** | Derlenmiş parçaları birleştirip bellekte nereye yerleşeceklerini belirleyen araç ve harita. |
| **Debugger (GDB)** | Programı durdurup içine bakmayı sağlayan araç. |
| **Breakpoint** | "Program buraya gelince dur" işareti. |
| **Register** | İşlemcinin içindeki çok hızlı, küçük bellek hücreleri. |
| **CSR** | İşlemcinin kendi ayarlarını tutan özel register'lar (`mtvec`, `mcause` vb.). |
| **Kesme (interrupt)** | Donanımın işlemciye "dur, önce bana bak" demesi. |
| **CLINT** | RISC-V'nin standart zamanlayıcı birimi (`mtime`, `mtimecmp`). |
| **Tick** | Zamanlayıcı kesmesinin her bir tetiklenmesi (bizde 100 ms'de bir). |
| **UART / seri port** | Harfleri tek tek, bit bit gönderen basit iletişim birimi. Gömülü sistemlerin "ekranı". |
| **Sürücü (driver)** | Belirli bir donanımla konuşmayı sağlayan kod (`uart.c`). |
| **Stack (yığın)** | Fonksiyonların geçici verilerini koyduğu bellek alanı. |
| **`volatile`** | Derleyiciye "bu değişken senin bilmediğin bir anda değişebilir, her seferinde yeniden oku" demek. |
| **`wfi`** | "Wait For Interrupt" — işlemciyi kesme gelene kadar uyutan komut. |
| **`mret`** | Kesmeden dönüp kesmeleri yeniden açan özel komut. |
| **Memory map** | Hangi donanımın hangi adreste olduğunu gösteren harita. |
| **JTAG** | Gerçek çipe program yüklemek ve debug etmek için kullanılan bağlantı standardı. |
| **OpenOCD** | GDB ile gerçek kart arasında JTAG köprüsü kuran yazılım. |
| **Libero SoC** | Microchip'in FPGA tasarım programı; Mi-V burada RTG4'e yerleştirilir. |
