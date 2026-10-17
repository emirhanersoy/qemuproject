/*
 * linker.ld  --  Bellek yerlesimi (memory layout).
 *
 * Derleyici .o dosyalarini uretir ama "hangi kod hangi adrese gidecek"
 * sorusunu bu dosya cevaplar. Gomulu sistemlerde linker script olmadan
 * dogru calisan bir imaj uretilemez: islemci resetten sonra belirli bir
 * adresten komut okumaya baslar, bizim de kodu tam oraya koymamiz gerekir.
 *
 * QEMU 'virt' makinesinde ve Mi-V referans tasarimlarinda RAM 0x80000000'da
 * baslar; _start bu adrese denk gelsin diye .init bolumunu en basa koyuyoruz.
 */

OUTPUT_ARCH("riscv")
OUTPUT_FORMAT("elf32-littleriscv")
ENTRY(_start)

MEMORY
{
    /* 8 MB yeterli; QEMU'ya -m 128M versek de linker bu sinirla calisir.
     * RTG4'te bu deger Libero tasarimindaki LSRAM/DDR boyutu olacak. */
    RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 8M
}

STACK_SIZE = 16K;   /* yigin: yerel degiskenler, fonksiyon cagrilari, kesmeler */
HEAP_SIZE  = 4K;    /* kullanmiyoruz ama sembolleri tanimli olsun */

SECTIONS
{
    /* --- Reset kodu: imajin en basi, yani 0x80000000 --- */
    .init : ALIGN(4)
    {
        KEEP(*(.init))
    } >RAM

    /* --- Calistirilabilir kod --- */
    .text : ALIGN(4)
    {
        *(.text.unlikely .text.unlikely.*)
        *(.text .text.*)
        *(.gnu.linkonce.t.*)
        . = ALIGN(4);
    } >RAM

    /* --- Sabitler: string literal'ler, const diziler --- */
    .rodata : ALIGN(4)
    {
        *(.rdata)
        *(.rodata .rodata.*)
        *(.srodata .srodata.*)
        *(.gnu.linkonce.r.*)
        . = ALIGN(4);
    } >RAM

    /* --- Baslangic degeri olan global degiskenler --- */
    .data : ALIGN(4)
    {
        _data_start = .;
        *(.data .data.*)
        *(.gnu.linkonce.d.*)

        . = ALIGN(8);
        /* gp register'i buradan +2KB'lik pencereye bakar; kucuk veri
         * erisimlerini tek komuta indirir (startup.S'te yukleniyor). */
        PROVIDE(__global_pointer$ = . + 0x800);
        *(.sdata .sdata.*)
        *(.sdata2 .sdata2.*)

        . = ALIGN(4);
        _data_end = .;
    } >RAM

    /* .data'nin imaj icindeki (yuklenme) adresi.
     * QEMU'da ELF dogrudan RAM'e yuklendigi icin bu deger _data_start'a
     * esit olur ve startup.S'teki kopyalama dongusu atlanir. */
    _data_load_start = LOADADDR(.data);

    /* --- Sifirla baslayan global degiskenler (imajda yer kaplamaz) --- */
    .bss (NOLOAD) : ALIGN(4)
    {
        _bss_start = .;
        *(.sbss .sbss.*)
        *(.scommon)
        *(.bss .bss.*)
        *(COMMON)
        . = ALIGN(4);
        _bss_end = .;
    } >RAM

    /* --- Heap ve Stack --- */
    .heap (NOLOAD) : ALIGN(8)
    {
        _heap_start = .;
        . += HEAP_SIZE;
        _heap_end = .;
    } >RAM

    .stack (NOLOAD) : ALIGN(16)
    {
        _stack_bottom = .;
        . += STACK_SIZE;
        _stack_top = .;          /* yigin yukaridan asagi buyur */
    } >RAM

    _ram_end = ORIGIN(RAM) + LENGTH(RAM);

    /* Tasma olursa derleme asamasinda hata ver; calisma aninda
     * anlasilmaz cokmelerle ugrasmaktan iyidir. */
    ASSERT(_stack_top <= _ram_end, "HATA: kod + heap + stack RAM'e sigmiyor")

    /DISCARD/ :
    {
        *(.comment)
        *(.note .note.*)
        *(.eh_frame .eh_frame.*)
        *(.riscv.attributes)
    }
}
