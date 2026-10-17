# =====================================================================
#  RTG4 / Mi-V RV32  --  QEMU Software-in-the-Loop firmware build
# ---------------------------------------------------------------------
#  Kullanim:
#     mingw32-make            -> firmware.elf uret
#     mingw32-make run        -> QEMU'da calistir (terminalde cikti)
#     mingw32-make debug      -> QEMU'yu durdurulmus halde + GDB sunucu
#     mingw32-make gdb        -> komut satirindan GDB ile baglan
#     mingw32-make clean      -> uretilen dosyalari sil
#     mingw32-make info       -> ayarlari goster
#
#  Linux/macOS'ta ayni komutlar 'make' ile calisir.
# =====================================================================

# Makineye ozgu arac yollari (kurulum scripti uretir, git'e girmez).
-include config.mk

# config.mk yoksa araclarin PATH'te oldugu varsayilir.
CROSS    ?= riscv-none-elf-
QEMU     ?= qemu-system-riscv32

CC       := $(CROSS)gcc
OBJCOPY  := $(CROSS)objcopy
OBJDUMP  := $(CROSS)objdump
SIZE     := $(CROSS)size
GDB      := $(CROSS)gdb

TARGET   ?= firmware

# Hedef platform secimi: PLATFORM_QEMU_VIRT veya PLATFORM_RTG4_MIV
# Ornek: mingw32-make PLATFORM=PLATFORM_RTG4_MIV
PLATFORM ?= PLATFORM_QEMU_VIRT

# Platform damgasi: son derlemenin hangi PLATFORM ile yapildigini tutar.
# PLATFORM degisince dosya yeniden yazilir -> tarihi yenilenir -> tum
# objeler yeniden derlenir. Bu olmasa QEMU objeleri "guncel" sayilir ve
# RTG4 derlemesi sessizce QEMU ikilisini uretirdi.
.DEFAULT_GOAL := all
PLATFORM_STAMP := platform.stamp
ifneq ($(file < $(PLATFORM_STAMP)),$(PLATFORM))
$(file > $(PLATFORM_STAMP),$(PLATFORM))
endif

# "make clean all" ayni komutta calisirsa damga silinmis olur; yeniden yaz.
$(PLATFORM_STAMP):
	$(file > $@,$(PLATFORM))

LDSCRIPT := linker.ld
HDRS     := platform.h riscv_csr.h uart.h
OBJS     := startup.o main.o uart.o

# ---------------------------------------------------------------------
#  Mimari secimi
# ---------------------------------------------------------------------
#  rv32   : Mi-V soft-core 32 bitlik (RV32)
#  i m a c: tamsayi + carpma/bolme + atomik + sikistirilmis komutlar
#  zicsr  : CSR komutlari (GCC 12+ bunu ayri istemek zorunda)
#  zifencei: fence.i komutu
#  ilp32  : donanim floating-point YOK (Mi-V'de FPU yok -> yazilim emulasyonu)
ARCHFLAGS := -march=rv32imac_zicsr_zifencei -mabi=ilp32 -mcmodel=medany

# -O0 ve -g3: debugger'da satir satir adimlama birebir calissin diye.
# Uretim derlemesinde -O2 -g yapilir.
CFLAGS := $(ARCHFLAGS) -O0 -g3 -gdwarf-4 \
	-Wall -Wextra -Wshadow -Wundef \
	-ffreestanding -fno-common -fno-builtin \
	-ffunction-sections -fdata-sections \
	-D$(PLATFORM)

ASFLAGS := $(ARCHFLAGS) -g3 -gdwarf-4 -D$(PLATFORM)

LDFLAGS := $(ARCHFLAGS) -T $(LDSCRIPT) \
	-nostdlib -nostartfiles -static \
	-Wl,--gc-sections \
	-Wl,-Map=$(TARGET).map \
	-Wl,--print-memory-usage \
	-Wl,--no-warn-rwx-segments

# libgcc: 64-bit bolme/carpma gibi islemler icin derleyici yardimci
# fonksiyonlari. Tam libc (newlib) baglamiyoruz, gerek yok.
LIBS := -lgcc

# ---------------------------------------------------------------------
#  QEMU parametreleri
# ---------------------------------------------------------------------
#  -machine virt : QEMU'nun genel RISC-V platformu (RTG4 modeli yok)
#  -bios none    : OpenSBI/bootloader yukleme, dogrudan bizim koda atla
#  -kernel *.elf : ELF'i RAM'e yukle ve entry point'ten basla
#  -nographic    : pencere acma, UART'i bu terminale bagla
QEMU_MACHINE := -machine virt -cpu rv32 -smp 1 -m 128M
QEMU_FLAGS   := $(QEMU_MACHINE) -nographic -bios none -kernel $(TARGET).elf

# Windows'ta 'del', digerlerinde 'rm -f'
ifeq ($(OS),Windows_NT)
RM_F := cmd /c del /q /f
else
RM_F := rm -f
endif

.PHONY: all run debug gdb clean info help

all: $(TARGET).elf

# ---------------------------------------------------------------------
#  Derleme kurallari
# ---------------------------------------------------------------------
%.o: %.c $(HDRS) Makefile $(PLATFORM_STAMP)
	@echo [CC]  $<
	@"$(CC)" $(CFLAGS) -c -o $@ $<

%.o: %.S $(HDRS) Makefile $(PLATFORM_STAMP)
	@echo [AS]  $<
	@"$(CC)" $(ASFLAGS) -c -o $@ $<

$(TARGET).elf: $(OBJS) $(LDSCRIPT) Makefile
	@echo [LD]  $@
	@"$(CC)" $(LDFLAGS) -o $@ $(OBJS) $(LIBS)
	@"$(OBJCOPY)" -O binary $@ $(TARGET).bin
	@"$(OBJCOPY)" -O ihex   $@ $(TARGET).hex
	@"$(OBJDUMP)" -d -S     $@ > $(TARGET).lst
	@"$(SIZE)" $@
	@echo Hazir: $(TARGET).elf + .bin .hex .map .lst

# ---------------------------------------------------------------------
#  Calistirma / hata ayiklama
# ---------------------------------------------------------------------
run: $(TARGET).elf
	@echo QEMU basliyor. Cikmak icin: Ctrl+A sonra X
	@"$(QEMU)" $(QEMU_FLAGS)

# -s : localhost:1234'te GDB sunucusu ac
# -S : islemciyi ilk komutta DURDURULMUS baslat (debugger baglanana kadar)
debug: $(TARGET).elf
	@echo QEMU durdurulmus halde basliyor, GDB sunucusu: localhost:1234
	@"$(QEMU)" $(QEMU_FLAGS) -s -S

gdb: $(TARGET).elf
	@"$(GDB)" $(TARGET).elf -ex "set architecture riscv:rv32" -ex "target remote localhost:1234"

clean:
	-@$(RM_F) $(OBJS) $(TARGET).elf $(TARGET).bin $(TARGET).hex $(TARGET).map $(TARGET).lst $(PLATFORM_STAMP)

info:
	@echo PLATFORM = $(PLATFORM)
	@echo CC       = $(CC)
	@echo QEMU     = $(QEMU)
	@echo GDB      = $(GDB)

help:
	@echo Hedefler: all run debug gdb clean info
