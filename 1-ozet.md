# 1-ozet.md — Proje, basitçe

> `1.md` çok ayrıntılıydı. Bu dosya aynı şeyleri **en basit haliyle**
> anlatıyor. Ayrıntı gerekirse `1.md`'ye bakarsın.

---

## 1. Proje tek paragrafta

Ekip RTG4 adlı bir çip için yazılım yazacak. **Çip henüz gelmedi.**
Beklemek yerine, o çipin içindeki işlemciyi bilgisayarda **taklit eden**
bir ortam kurdum. Böylece ekip bugünden C kodu yazıp çalıştırabiliyor,
hata ayıklayabiliyor.

Şu an üstünde çalışan kod basit: ekrana "Hello, World!" yazıyor ve her
saniye bir satır basıyor. Ama **ortamın kendisi** basit değil — asıl iş
orada.

---

## 2. Neden taklit, neden QEMU

- Gerçek kart yok → yazılım bekleyemez
- İlk tercih **Simics**'ti → **lisans alınamadı**
- Alternatif: **QEMU** → ücretsiz, RISC-V işlemcileri taklit edebiliyor

Müdür de QEMU dedi, zaten doğru tercih.

---

## 3. Anlaşılması gereken tek önemli şey

**RTG4 bir işlemci değil, boş bir çip (FPGA).**

Benzetme: RTG4 **boş bir arsa** gibi. İçine ne isterseniz inşa
edersiniz. Biz de içine bir işlemci inşa ediyoruz.

İnşa edilen işlemci: **RISC-V** tipinde. Microchip bunun hazır tasarımını
veriyor, adı **Mi-V**.

> Yani "RTG4 işlemcisi" demek aslında "RTG4'ün içine kurulmuş RISC-V
> işlemcisi" demek.

**Bunun bizim için sonucu:** QEMU'da RTG4 diye bir seçenek yok, ama
**RISC-V var**. Biz de o RISC-V'yi kullandık.

---

## 4. Ne aynı, ne farklı

| | Gerçek RTG4 | Bizim ortam |
|---|---|---|
| İşlemcinin komutları | RISC-V | RISC-V → **aynı** |
| Kesme (alarm) sistemi | RISC-V standardı | → **aynı** |
| Çevre birimlerin adresleri | Farklı sayılar | Farklı sayılar → **fark burada** |

**İlk iki satır aynı olduğu için bu ortam işe yarıyor.**
Üçüncü satır da çözüldü → bir sonraki başlık.

---

## 5. Projenin en akıllı kısmı

Kodun hiçbir yerinde **sayı** yazmıyoruz. Adreslerin hepsi tek bir
dosyada (`platform.h`) **isim** olarak duruyor.

Yani `main.c` şöyle demiyor:

```c
0x02000000 adresine yaz        // kötü
```

Şöyle diyor:

```c
CLINT_BASE adresine yaz        // iyi
```

`CLINT_BASE`'in ne olduğu `platform.h`'de yazılı ve iki sürümü var:
biri QEMU için, biri RTG4 için.

**Sonucu:** Hedefi değiştirmek tek komut:

```powershell
mingw32-make                              # QEMU için
mingw32-make PLATFORM=PLATFORM_RTG4_MIV   # RTG4 için
```

`main.c`'nin **tek satırı değişmiyor**. Kart geldiğinde kodu yeniden
yazmaya gerek yok.

---

## 6. Kullandığımız 4 araç

| Araç | Ne işe yarar | Benzetme |
|---|---|---|
| `riscv-none-elf-gcc` | C kodunu RISC-V'nin anladığı dile çevirir | **Çevirmen** |
| `qemu-system-riscv32` | RISC-V işlemcisini taklit eder | **Sahne** |
| `riscv-none-elf-gdb` | Kodu durdurup içine bakmayı sağlar | **Röntgen** |
| `mingw32-make` | Derleme komutlarını otomatik çalıştırır | **Şef** |

Hepsi ücretsiz, hepsi bu projede sıfırdan kuruldu, yönetici yetkisi
gerekmedi.

> **Not:** Normal `gcc` işimize yaramaz, çünkü o bu bilgisayar için kod
> üretir. Bize RISC-V için kod üreten bir derleyici gerekiyor. İsmindeki
> `riscv` bu yüzden var.

---

## 7. Dosyalar — her biri bir cümle

### Asıl kod (7 dosya)

| Dosya | Ne yapıyor |
|---|---|
| **`platform.h`** | Tüm adreslerin isim listesi. **Projenin kalbi.** |
| **`main.c`** | Uygulama: ekrana yazar, saniyeleri sayar, kesmeyi işler |
| **`startup.S`** | İşlemci açıldığında ilk çalışan kod. Ortamı hazırlar |
| **`uart.c`** | Ekrana yazı yazma işini yapan sürücü |
| **`uart.h`** | `uart.c`'nin sunduğu fonksiyonların listesi |
| **`linker.ld`** | "Hangi kod hangi adrese gidecek" planı |
| **`riscv_csr.h`** | İşlemcinin ayar düğmelerine erişim kısayolları |

### Yardımcılar

| Dosya | Ne yapıyor |
|---|---|
| **`Makefile`** | "Derle", "çalıştır", "temizle" komutlarını tanımlar |
| **`.vscode/`** | VSCode entegrasyonu — Ctrl+Shift+B ve F5 bundan çalışıyor |
| **`tools/setup.ps1`** | Yeni bir bilgisayarda her şeyi tek komutla kurar |
| **`tools/smoke-test.ps1`** | 10 kontrol yapar, "her şey çalışıyor mu" sorusuna cevap verir |

---

## 8. En çok merak edilen 3 dosya, biraz daha açık

### `startup.O` ne demek — `startup.S`

İşlemci elektrik verildiğinde **hiçbir şey hazır değil**. C kodu
çalışabilmesi için önce bazı şeylerin kurulması lazım:

1. Kesmeleri kapat (henüz hazır değiliz)
2. **Yığın (stack) kur** — fonksiyonların çalışabilmesi için şart
3. Global değişkenleri sıfırla
4. **Kesme olduğunda nereye gidileceğini söyle**
5. `main()`'i çağır

Bu beş iş `startup.S`'te yapılıyor. Neden C değil assembly: bu işler C'den
yapılamaz, çünkü C'nin çalışabilmesi için **zaten bunların yapılmış
olması** gerekiyor. Tavuk-yumurta durumu.

### `linker.ld` neden gerekli

Normal bilgisayarda program çalıştırdığında Windows onu bir yere yükler,
sen karışmazsın.

Gömülü sistemde **Windows yok**. İşlemci elektrik verildiğinde belirli bir
adresten komut okumaya başlıyor. Senin de kodu **tam oraya** koyman
gerekiyor. `linker.ld` bu planı veriyor.

Bizim durumda kod `0x80000000` adresine konuyor.

### `platform.h` — zaten §5'te anlattım

Tüm adreslerin isim listesi. İki sürüm: QEMU ve RTG4.

---

## 9. Kesme (interrupt) nedir — alarm saati benzetmesi

**Kesme = alarm.**

Normal akış: program satır satır çalışır.
Kesme olduğunda: program **aniden durur**, başka bir fonksiyona atlar,
orada işini yapar, sonra **kaldığı yere geri döner**.

Bizim örnekte alarm **her 100 milisaniyede** çalıyor.

### Kodda nasıl çalışıyor

```
main() çalışıyor...
    │
    │  (100 ms sonra alarm çaldı)
    ▼
trap_handler() → sayacı 1 artır → alarmı yeniden kur
    │
    │  (işi bitti)
    ▼
main() kaldığı yerden devam
```

### Dikkat edilecek **tek** şey

RISC-V'nin alarmı **tek seferlik**. Yani çaldıktan sonra kendini
yeniden kurmuyor.

Benzetme: Telefonundaki alarm "her gün tekrar et" seçeneği **kapalı**
gibi. Çalar, susar, bitti. Bir daha çalması için **elle yeniden kurman**
gerekiyor.

Kodda bunu yapan satır (`main.c` satır 87):

```c
timer_schedule_next();   // alarmı yeniden kur
```

**Bu satır silinirse sistem tamamen susar.** Projenin en kritik tek satırı.

### `wfi` nedir

`main` içindeki döngüde `wfi` komutu var. Anlamı: **"alarm çalana kadar
uyu"**.

Boş döngüde beklemek yerine uyumak:
- Gerçek donanımda pil tasarrufu
- QEMU'da bilgisayarı yormaz

---

## 10. Program nasıl çalışıyor — 6 adım

```
1. QEMU açılır, kodu belleğe yükler
2. startup.S çalışır → ortamı hazırlar
3. main() başlar
4. Ekrana banner basar (Hello World + adresler)
5. Alarmı kurar
6. Uyumaya başlar → her 100 ms'de uyanır → sayar → her saniyede bir satır basar
```

Ekranda gördüğün `[tick 10] uptime = 1 s` satırı **10 tane gerçek
alarmın** sonucu.

---

## 11. Bu ortam ne yapar, ne yapmaz

### ✅ Yapar
- Kodun mantığı doğru mu → **test edebilirsin**
- Kesme/zamanlayıcı mantığı → **test edebilirsin**
- Zaman hesapları → **test edebilirsin**
- "Çalışan bir şey bozuldu mu" → **test edebilirsin**

### ❌ Yapmaz
- Gerçek çevre birimlerin davranışı (gerçek seri port, SPI, GPIO)
- Sıcaklık, radyasyon, elektriksel etkiler
- "Bu komut kaç mikrosaniye sürer" sorusu

### Nasıl söylemeli

> "Bu ortam **yazılım mantığını** doğrular, **donanım davranışını**
> doğrulamaz."

Gömülü projelerde hataların çoğu birinci gruptadır. O yüzden bu ortam
bugünden işe yarar.

---

## 12. Yol haritası

| Aşama | Ne | Durum |
|---|---|---|
| **1** | Bu ortam | ✅ **Bitti** |
| **2** | `platform.h`'deki RTG4 adreslerini doğrula (5 sayı) | Kart gelmeden yapılabilir |
| **3** | Gerçek kartta çalıştır | Kart bekleniyor |
| **4** | Çevre birimleri de taklit et | Opsiyonel, haftalar sürer |

**Aşama 2 için gereken 5 sayı:** bellek adresi, zamanlayıcı adresi, seri
port adresi, iki saat frekansı. Bunlar donanım/FPGA tarafından gelecek.

---

## 13. Sunumda söyleyeceğin 5 cümle

1. "RTG4 için yazılım geliştirme ortamı kurdum, kart gelmeden çalışıyor."
2. "İşlemcinin komutları ve kesme sistemi gerçek çipte de birebir aynı."
3. "Farklı olan kısım çevre birimlerin adresleri; onları tek bir dosyada
   topladım, kart gelince o dosyadaki 5 sayıyı doğrulamak yeterli."
4. "VSCode'da Ctrl+Shift+B derliyor, F5 debug başlatıyor — ekip ek bir
   şey öğrenmek zorunda değil."
5. "Her değişiklikten sonra kendini test eden bir betik var, şu an 10/10
   geçiyor."

---

## 14. Söylerken dikkat

| ❌ Deme | ✅ De |
|---|---|
| "RTG4'ü simüle ediyoruz" | "RTG4'ün içindeki RISC-V işlemciyi hedefliyoruz" |
| "Kart gelince kod doğrudan çalışır" | "Kod derlenir, adreslerin doğrulanması gerekir" |
| "Gerçek kartta test ettim" | "Gerçek kart hedefi için **derlendiğini** doğruladım" |

> Son ikisi önemli: gerçek kartta **hiç denenmedi**, sadece derlendi.
