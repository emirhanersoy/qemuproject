/*
 * startup.S  --  Islemci acilis (reset) kodu ve kesme giris noktasi.
 *
 * Islemci resetten cikinca C dili icin gerekli hicbir sey hazir degildir:
 * yigin (stack) yoktur, global degiskenler sifirlanmamistir. Bu dosya o
 * ortami kurup main()'e atlar. "C runtime startup" veya "crt0" denir.
 *
 * Dosya uzantisi buyuk .S cunku on-islemciden (preprocessor) gecmesini
 * istiyoruz; kucuk .s olsaydi #define/#include kullanamazdik.
 */

    .section .init, "ax"
    .global _start
    .type   _start, @function

_start:
    /* --- 1) Kesmeleri kapali tut: henuz stack bile yok --- */
    csrw    mstatus, zero
    csrw    mie, zero

    /* --- 2) gp (global pointer) kurulumu ---
     * Kucuk veri optimizasyonu icin GCC degiskenlere gp-bagil erisir.
     * Bu iki komut relax EDILMEMELI, yoksa gp'yi gp ile yuklemeye calisir.
     */
    .option push
    .option norelax
    la      gp, __global_pointer$
    .option pop

    /* --- 3) Yigin isaretcisi (stack pointer) --- */
    la      sp, _stack_top

    /* --- 4) .data bolumunu ROM'dan RAM'e kopyala ---
     * QEMU'da ELF dogrudan RAM'e yuklendigi icin kaynak = hedef olur ve
     * dongu hemen biter. Gercek RTG4'te kod eNVM'den calisacagi icin bu
     * kopyalama SART. Ayni kod iki durumda da dogru calisir.
     */
    la      a0, _data_load_start
    la      a1, _data_start
    la      a2, _data_end
    beq     a0, a1, 2f              /* adresler ayniysa kopyalama gereksiz */
1:  bgeu    a1, a2, 2f
    lw      t0, 0(a0)
    sw      t0, 0(a1)
    addi    a0, a0, 4
    addi    a1, a1, 4
    j       1b
2:

    /* --- 5) .bss bolumunu sifirla (C standardi bunu sart kosar) --- */
    la      a0, _bss_start
    la      a1, _bss_end
3:  bgeu    a0, a1, 4f
    sw      zero, 0(a0)
    addi    a0, a0, 4
    j       3b
4:

    /* --- 6) Kesme vektorunu kur: mtvec = trap_entry, mod = Direct ---
     * mtvec'in alt 2 biti mod secer: 00 = Direct (tum trap'ler tek adrese),
     * 01 = Vectored. trap_entry 4'e hizali oldugu icin alt bitler 0.
     */
    la      t0, trap_entry
    csrw    mtvec, t0

    /* --- 7) C dunyasina gec --- */
    li      a0, 0                   /* argc */
    li      a1, 0                   /* argv */
    call    main

    /* main asla donmemeli; donerse islemciyi uyut */
_exit_loop:
    wfi
    j       _exit_loop
    .size   _start, . - _start


/*
 * trap_entry  --  TUM kesme ve exception'larin donanim tarafindan
 *                 atladigi tek giris noktasi.
 *
 * Neden assembly? Cunku kesme, C fonksiyonunun ortasinda aniden olur.
 * Kesilen kodun register'larini bozmamak icin once onlari yigina
 * kaydetmeliyiz. Ayrica normal C fonksiyonu 'ret' ile doner; kesmeden
 * donmek icin 'mret' gerekir (mret ayni zamanda mstatus.MIE'yi geri yukler).
 *
 * Sadece "caller-saved" (gecici) register'lari kaydediyoruz: trap_handler
 * normal bir C fonksiyonu oldugu icin kalici register'lari kendisi korur.
 */
    .section .text
    .balign 4
    .global trap_entry
    .type   trap_entry, @function

trap_entry:
    addi    sp, sp, -64
    sw      ra, 0(sp)
    sw      t0, 4(sp)
    sw      t1, 8(sp)
    sw      t2, 12(sp)
    sw      a0, 16(sp)
    sw      a1, 20(sp)
    sw      a2, 24(sp)
    sw      a3, 28(sp)
    sw      a4, 32(sp)
    sw      a5, 36(sp)
    sw      a6, 40(sp)
    sw      a7, 44(sp)
    sw      t3, 48(sp)
    sw      t4, 52(sp)
    sw      t5, 56(sp)
    sw      t6, 60(sp)

    call    trap_handler            /* asil is C tarafinda yapilir */

    lw      ra, 0(sp)
    lw      t0, 4(sp)
    lw      t1, 8(sp)
    lw      t2, 12(sp)
    lw      a0, 16(sp)
    lw      a1, 20(sp)
    lw      a2, 24(sp)
    lw      a3, 28(sp)
    lw      a4, 32(sp)
    lw      a5, 36(sp)
    lw      a6, 40(sp)
    lw      a7, 44(sp)
    lw      t3, 48(sp)
    lw      t4, 52(sp)
    lw      t5, 56(sp)
    lw      t6, 60(sp)
    addi    sp, sp, 64

    mret                            /* kesilen yere geri don */
    .size   trap_entry, . - trap_entry
