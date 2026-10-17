/*
 * riscv_csr.h  --  RISC-V makine seviyesi (machine mode) CSR erisim yardimcilari.
 *
 * CSR = Control and Status Register. Bunlar bellekte DEGIL, islemcinin
 * icindedir; sadece csrr/csrw gibi ozel komutlarla okunup yazilir.
 * Kesme (interrupt) mekanizmasinin tamami bu register'lar uzerinden kurulur.
 */
#ifndef RISCV_CSR_H
#define RISCV_CSR_H

#include <stdint.h>

#define csr_read(reg)                                                   \
    ({ uint32_t __v;                                                    \
       __asm__ volatile ("csrr %0, " #reg : "=r"(__v));                 \
       __v; })

#define csr_write(reg, val)                                             \
    __asm__ volatile ("csrw " #reg ", %0" :: "rK"((uint32_t)(val)))

#define csr_set(reg, val)   /* belirtilen bitleri 1 yap */              \
    __asm__ volatile ("csrs " #reg ", %0" :: "rK"((uint32_t)(val)))

#define csr_clear(reg, val) /* belirtilen bitleri 0 yap */              \
    __asm__ volatile ("csrc " #reg ", %0" :: "rK"((uint32_t)(val)))

/* mstatus: global kesme izni */
#define MSTATUS_MIE   (1UL << 3)   /* Machine Interrupt Enable         */
#define MSTATUS_MPIE  (1UL << 7)   /* trap oncesi MIE degeri           */

/* mie: hangi kesme kaynagi acik */
#define MIE_MSIE      (1UL << 3)   /* yazilim kesmesi                  */
#define MIE_MTIE      (1UL << 7)   /* ZAMANLAYICI kesmesi (bizim isimiz)*/
#define MIE_MEIE      (1UL << 11)  /* harici (PLIC) kesmesi            */

/* mcause: en ust bit 1 ise kesme, 0 ise exception (hata) */
#define MCAUSE_IRQ_FLAG   (1UL << 31)
#define MCAUSE_CODE_MASK  0x7FFFFFFFUL

/* mcause kodlari -- kesmeler */
#define IRQ_M_SOFT    3
#define IRQ_M_TIMER   7
#define IRQ_M_EXT     11

/* mcause kodlari -- exception'lar (en sik gorulenler) */
#define EXC_INSN_MISALIGNED   0
#define EXC_INSN_FAULT        1
#define EXC_ILLEGAL_INSN      2
#define EXC_BREAKPOINT        3
#define EXC_LOAD_MISALIGNED   4
#define EXC_LOAD_FAULT        5
#define EXC_STORE_MISALIGNED  6
#define EXC_STORE_FAULT       7
#define EXC_ECALL_M           11

#endif /* RISCV_CSR_H */
