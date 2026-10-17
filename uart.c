/*
 * uart.c  --  UART surucusu.
 *
 * Iki farkli donanim destekler, secim platform.h uzerinden derleme aninda
 * yapilir:
 *   - NS16550A        : QEMU 'virt' makinesinin UART0'i (PC uyumlu klasik)
 *   - CoreUARTapb     : Microchip'in RTG4/Mi-V tasarimlarinda kullandigi IP
 */
#include "platform.h"
#include "uart.h"

/* ---------------------------- NS16550A ---------------------------- */
#if defined(UART_IS_NS16550)

#define U8(off) MMIO8(UART_BASE + (off) * UART_REG_STRIDE)

#define NS16550_THR  0   /* yazma: gonderilecek veri                   */
#define NS16550_IER  1   /* kesme izinleri                             */
#define NS16550_FCR  2   /* FIFO kontrol                               */
#define NS16550_LCR  3   /* hat kontrol (veri bit sayisi, DLAB)        */
#define NS16550_LSR  5   /* hat durumu                                 */
#define NS16550_DLL  0   /* DLAB=1 iken: baud bolucu, alt byte         */
#define NS16550_DLM  1   /* DLAB=1 iken: baud bolucu, ust byte         */

#define LSR_THRE     (1u << 5)   /* gonderme register'i bos            */

void uart_init(void)
{
    U8(NS16550_IER) = 0x00;         /* kesmeleri kapat (polling)       */
    U8(NS16550_LCR) = 0x80;         /* DLAB=1 -> baud ayarina gec      */
    U8(NS16550_DLL) = 0x01;         /* bolucu = 1 (QEMU zaten onemsemez)*/
    U8(NS16550_DLM) = 0x00;
    U8(NS16550_LCR) = 0x03;         /* DLAB=0, 8 veri biti, parity yok */
    U8(NS16550_FCR) = 0x07;         /* FIFO ac + temizle               */
}

void uart_putc(char c)
{
    while ((U8(NS16550_LSR) & LSR_THRE) == 0) {
        /* gonderme tamponu bosalana kadar bekle */
    }
    U8(NS16550_THR) = (uint8_t)c;
}

/* -------------------------- CoreUARTapb --------------------------- */
#elif defined(UART_IS_COREUARTAPB)

#define CU(off) MMIO32(UART_BASE + (off))

#define CUAPB_TXDATA   0x00
#define CUAPB_RXDATA   0x04
#define CUAPB_CTRL1    0x08   /* baud bolucu [7:0]                    */
#define CUAPB_CTRL2    0x0C   /* baud bolucu [12:8] + veri bit/parity  */
#define CUAPB_STATUS   0x10
#define CUAPB_TXRDY    (1u << 0)

void uart_init(void)
{
    /* baud_value = (PCLK / (16 * baud)) - 1  */
    uint32_t div = (UART_PCLK_HZ / (16UL * UART_BAUD)) - 1UL;

    CU(CUAPB_CTRL1) = div & 0xFFu;
    /* CTRL2: [7:5]=veri bit/parity ayari (8 bit, parity yok), [4:0]=div ust */
    CU(CUAPB_CTRL2) = ((div >> 8) & 0x1Fu) | (1u << 5);
}

void uart_putc(char c)
{
    while ((CU(CUAPB_STATUS) & CUAPB_TXRDY) == 0) {
    }
    CU(CUAPB_TXDATA) = (uint8_t)c;
}

#else
#  error "platform.h icinde UART tipi secilmedi"
#endif

/* ------------------- donanimdan bagimsiz kisim -------------------- */

void uart_puts(const char *s)
{
    while (*s != '\0') {
        if (*s == '\n') {
            uart_putc('\r');        /* terminaller CR+LF bekler */
        }
        uart_putc(*s++);
    }
}

void uart_put_u32(uint32_t v)
{
    char buf[11];
    int i = 0;

    if (v == 0) {
        uart_putc('0');
        return;
    }
    while (v > 0) {
        buf[i++] = (char)('0' + (v % 10u));
        v /= 10u;
    }
    while (i > 0) {
        uart_putc(buf[--i]);
    }
}

void uart_put_hex32(uint32_t v)
{
    static const char hex[] = "0123456789ABCDEF";

    uart_puts("0x");
    for (int shift = 28; shift >= 0; shift -= 4) {
        uart_putc(hex[(v >> shift) & 0xFu]);
    }
}
