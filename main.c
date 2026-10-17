/*
 * main.c  --  RTG4 / Mi-V RV32 firmware: "Hello World" + periyodik
 *             zamanlayici kesmesi (timer interrupt).
 *
 * Akis:
 *   startup.S  ->  main()  ->  timer_start()  ->  sonsuz dongu (wfi)
 *                                   |
 *                    her 100 ms'de donanim kesme uretir
 *                                   v
 *   startup.S:trap_entry  ->  trap_handler()  ->  sayac++ , sonraki kesmeyi kur
 */
#include "platform.h"
#include "riscv_csr.h"
#include "uart.h"

#define HART_ID            0u      /* tek cekirdek (single hart) */
#define TICK_HZ            10u     /* saniyede 10 kesme = 100 ms periyot */
#define TICKS_PER_SECOND   TICK_HZ

/* mtime sayacinin iki kesme arasinda ilerlemesi gereken adim sayisi */
#define MTIME_STEP         (MTIME_FREQ_HZ / TICK_HZ)

/*
 * 'volatile': bu degiskenler kesme icinde degisir. volatile olmasa
 * derleyici "main dongusunde kimse degistirmiyor" diye optimize edip
 * degeri register'da onbellekler ve degisimi hic gormezdik.
 */
volatile uint32_t g_tick_count   = 0;
volatile uint32_t g_spurious_irq = 0;

/* ------------------------------------------------------------------ */
/*  CLINT zamanlayici erisimi                                         */
/* ------------------------------------------------------------------ */

/*
 * mtime 64 bitlik, ama RV32'de tek seferde 32 bit okuyabiliyoruz.
 * Alt kelimeyi okurken ust kelime tasma yapabilir; bu yuzden
 * "ust-alt-ust" okuyup ust degismediginden emin oluyoruz.
 */
static uint64_t mtime_read(void)
{
    uint32_t hi, lo;

    do {
        hi = MMIO32(CLINT_MTIME_HI);
        lo = MMIO32(CLINT_MTIME_LO);
    } while (hi != MMIO32(CLINT_MTIME_HI));

    return ((uint64_t)hi << 32) | (uint64_t)lo;
}

/*
 * mtimecmp yazmak da 64 bit. Araya yanlis bir ara deger yazip istemeden
 * kesme tetiklememek icin RISC-V spesifikasyonunun onerdigi sira:
 *   1) alt kelimeyi maksimuma cek (artik kesme tetiklenemez)
 *   2) ust kelimeyi yaz
 *   3) alt kelimeyi gercek degere yaz
 */
static void mtimecmp_write(uint64_t value)
{
    MMIO32(CLINT_MTIMECMP_LO(HART_ID)) = 0xFFFFFFFFu;
    MMIO32(CLINT_MTIMECMP_HI(HART_ID)) = (uint32_t)(value >> 32);
    MMIO32(CLINT_MTIMECMP_LO(HART_ID)) = (uint32_t)(value & 0xFFFFFFFFu);
}

/*
 * RISC-V zamanlayicisi "one-shot"tur: kesme olustugunda kendini
 * otomatik yeniden kurmaz. Periyodik davranis icin her kesmede
 * bir sonraki hedefi elimizle ileri almamiz gerekir.
 */
static void timer_schedule_next(void)
{
    mtimecmp_write(mtime_read() + (uint64_t)MTIME_STEP);
}

static void timer_start(void)
{
    timer_schedule_next();          /* ilk hedefi koy                   */
    csr_set(mie, MIE_MTIE);         /* zamanlayici kesmesini ac         */
    csr_set(mstatus, MSTATUS_MIE);  /* global kesmeleri ac -> artik canli */
}

/* ------------------------------------------------------------------ */
/*  Kesme / exception isleyicisi                                      */
/*  (startup.S icindeki trap_entry buraya atlar)                      */
/* ------------------------------------------------------------------ */
void trap_handler(void)
{
    uint32_t mcause = csr_read(mcause);
    uint32_t code   = mcause & MCAUSE_CODE_MASK;

    if (mcause & MCAUSE_IRQ_FLAG) {
        /* ---- Kesme (interrupt) ---- */
        switch (code) {
        case IRQ_M_TIMER:
            g_tick_count++;
            timer_schedule_next();  /* periyodikligi saglayan satir */
            break;

        default:
            g_spurious_irq++;
            break;
        }
    } else {
        /* ---- Exception: programda gercek bir hata var ----
         * Burada devam etmek anlamsiz; bilgiyi bas ve dur.
         * Debugger ile buraya breakpoint koymak hata avinda cok ise yarar.
         */
        uart_puts("\n*** EXCEPTION ***\n");
        uart_puts("  mcause = ");  uart_put_hex32(mcause);
        uart_puts("\n  mepc   = ");  uart_put_hex32(csr_read(mepc));
        uart_puts("\n  mtval  = ");  uart_put_hex32(csr_read(mtval));
        uart_puts("\nSistem durduruldu.\n");

        for (;;) {
            __asm__ volatile ("wfi");
        }
    }
}

/* ------------------------------------------------------------------ */
/*  Uygulama                                                          */
/* ------------------------------------------------------------------ */
static void print_banner(void)
{
    uart_puts("\n");
    uart_puts("===========================================\n");
    uart_puts(" Hello, World!\n");
    uart_puts(" RTG4 / Mi-V RV32 firmware - QEMU SiL\n");
    uart_puts("===========================================\n");
    uart_puts(" Platform   : "); uart_puts(PLATFORM_NAME); uart_puts("\n");
    uart_puts(" RAM base   : "); uart_put_hex32(RAM_BASE);   uart_puts("\n");
    uart_puts(" CLINT base : "); uart_put_hex32(CLINT_BASE); uart_puts("\n");
    uart_puts(" UART base  : "); uart_put_hex32(UART_BASE);  uart_puts("\n");
    uart_puts(" mtime freq : "); uart_put_u32(MTIME_FREQ_HZ); uart_puts(" Hz\n");
    uart_puts(" Tick       : "); uart_put_u32(1000u / TICK_HZ); uart_puts(" ms\n");
    uart_puts("-------------------------------------------\n");
}

int main(void)
{
    uint32_t reported = 0;

    uart_init();
    print_banner();

    timer_start();
    uart_puts("Zamanlayici kesmesi aktif. Sayac ilerliyor...\n\n");

    for (;;) {
        /*
         * wfi = Wait For Interrupt. Islemciyi kesme gelene kadar uyutur.
         * Bos dongude beklemek yerine bunu kullanmak gercek donanimda
         * guc tasarrufu, QEMU'da ise ana makinenin CPU'sunu yemez.
         */
        __asm__ volatile ("wfi");

        uint32_t now = g_tick_count;

        /* Her tam saniyede bir rapor bas */
        if (now != reported && (now % TICKS_PER_SECOND) == 0u) {
            reported = now;
            uart_puts("[tick ");
            uart_put_u32(now);
            uart_puts("] uptime = ");
            uart_put_u32(now / TICKS_PER_SECOND);
            uart_puts(" s\n");
        }
    }

    return 0;   /* buraya asla gelinmez */
}
