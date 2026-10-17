/*
 * uart.h  --  Minimal seri port (UART) surucusu arayuzu.
 *
 * Gomulu sistemlerde printf lukstur: newlib'in printf'i hem buyuktur hem de
 * altinda isletim sistemi cagrilari (syscall) bekler. Bunun yerine dogrudan
 * UART register'ina byte yazan kendi fonksiyonlarimizi kullaniyoruz.
 */
#ifndef UART_H
#define UART_H

#include <stdint.h>

void uart_init(void);
void uart_putc(char c);
void uart_puts(const char *s);          /* satir sonu eklemez */
void uart_put_u32(uint32_t v);          /* ondalik (decimal)  */
void uart_put_hex32(uint32_t v);        /* 0x???????? formati */

#endif /* UART_H */
