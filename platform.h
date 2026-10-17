/*
 * platform.h  --  Hedef platformun bellek haritasi (memory map).
 *
 * Bu dosya projenin en kritik parcasi: uygulama kodu (main.c) hicbir zaman
 * cipe ozgu adres yazmaz, sadece burada tanimli isimleri kullanir.
 * Boylece ayni kaynak kod iki hedef icin derlenebilir:
 *
 *   PLATFORM_QEMU_VIRT  -> QEMU'nun 'virt' makinesi (bugun, kart yokken)
 *   PLATFORM_RTG4_MIV   -> RTG4 FPGA uzerindeki MIV_RV32 soft-core (kart gelince)
 *
 * Secim Makefile'dan -D ile yapilir (varsayilan: QEMU).
 */
#ifndef PLATFORM_H
#define PLATFORM_H

#include <stdint.h>

#if !defined(PLATFORM_QEMU_VIRT) && !defined(PLATFORM_RTG4_MIV)
#  define PLATFORM_QEMU_VIRT 1
#endif

/* Donanim register erisimi: derleyici asla optimize edip atmasin -> volatile */
#define MMIO8(a)  (*(volatile uint8_t  *)(uintptr_t)(a))
#define MMIO32(a) (*(volatile uint32_t *)(uintptr_t)(a))

/* ------------------------------------------------------------------ */
/*  Hedef 1: QEMU riscv32 "virt"                                      */
/* ------------------------------------------------------------------ */
#if defined(PLATFORM_QEMU_VIRT)

#define PLATFORM_NAME       "QEMU riscv32 'virt' (RTG4/Mi-V vekili)"

#define RAM_BASE            0x80000000UL   /* DRAM taban adresi            */
#define CLINT_BASE          0x02000000UL   /* QEMU virt CLINT              */
#define MTIME_FREQ_HZ       10000000UL     /* QEMU virt mtime = 10 MHz     */

#define UART_BASE           0x10000000UL   /* NS16550A uyumlu UART0        */
#define UART_IS_NS16550     1
#define UART_REG_STRIDE     1              /* register'lar 1 byte aralikli */

/* ------------------------------------------------------------------ */
/*  Hedef 2: RTG4 + MIV_RV32 (gercek donanim)                         */
/* ------------------------------------------------------------------ */
#elif defined(PLATFORM_RTG4_MIV)

#define PLATFORM_NAME       "RTG4 / MIV_RV32 soft-core"

/*
 * DIKKAT: Asagidaki adresler Mi-V referans tasarimlarindaki tipik
 * degerlerdir. RTG4 bir FPGA oldugu icin cevre birimlerin adresleri
 * Libero SoC tasarimina gore DEGISIR. Kart/bitstream geldiginde
 * Libero'daki "Memory Map" raporundan dogrulanmalidir.
 */
#define RAM_BASE            0x80000000UL   /* LSRAM / TCM                  */
#define CLINT_BASE          0x44000000UL   /* MIV_RV32 dahili CLINT        */
#define MTIME_FREQ_HZ       50000000UL     /* Libero'daki SYS_CLK'e gore   */

#define UART_BASE           0x70001000UL   /* CoreUARTapb (tasarima bagli) */
#define UART_IS_COREUARTAPB 1
#define UART_REG_STRIDE     4
#define UART_PCLK_HZ        50000000UL
#define UART_BAUD           115200UL

#endif

/* ------------------------------------------------------------------ */
/*  CLINT  --  standart RISC-V makine seviyesi zamanlayici            */
/*  (hem QEMU virt hem Mi-V ayni register duzenini kullanir,          */
/*   sadece taban adres farkli)                                       */
/* ------------------------------------------------------------------ */
#define CLINT_MSIP(hart)        (CLINT_BASE + 0x0000UL + 4UL * (hart))
#define CLINT_MTIMECMP_LO(hart) (CLINT_BASE + 0x4000UL + 8UL * (hart))
#define CLINT_MTIMECMP_HI(hart) (CLINT_BASE + 0x4004UL + 8UL * (hart))
#define CLINT_MTIME_LO          (CLINT_BASE + 0xBFF8UL)
#define CLINT_MTIME_HI          (CLINT_BASE + 0xBFFCUL)

#endif /* PLATFORM_H */
