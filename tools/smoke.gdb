# ---------------------------------------------------------------------
#  smoke.gdb -- Debug zincirinin otomatik dogrulamasi.
#  tools\smoke-test.ps1 tarafindan calistirilir.
# ---------------------------------------------------------------------
set confirm off
set pagination off
set architecture riscv:rv32
target remote localhost:1234

printf "\n[1] Baglanti aninda PC (QEMU reset vektoru)\n"
info registers pc

printf "\n[2] main() icinde breakpoint\n"
break main
continue
info line

printf "\n[3] Kesme vektoru dogru kurulmus mu? (startup.S -> csrw mtvec)\n"
printf "    mtvec      = 0x%08x\n", $mtvec
printf "    trap_entry = 0x%08x   <- ikisi ayni olmali\n", &trap_entry

printf "\n[4] Zamanlayici kesmesini yakala\n"
break trap_handler
continue
printf "    mcause  = 0x%08x   <- beklenen 0x80000007 (machine timer irq)\n", $mcause
printf "    mepc    = 0x%08x   <- kesilen komutun adresi\n", $mepc
printf "    mie     = 0x%08x   <- bit7 (MTIE) set olmali\n", $mie
printf "    mstatus = 0x%08x   <- trap icinde MIE(bit3)=0, MPIE(bit7)=1\n", $mstatus
print g_tick_count
backtrace

printf "\n[5] Iki kesme daha -> sayac ilerliyor mu?\n"
continue
continue
print g_tick_count

printf "\n[6] CLINT register'larini canli oku\n"
printf "    mtime    lo/hi : "
x/2xw 0x0200bff8
printf "    mtimecmp lo/hi : "
x/2xw 0x02004000

printf "\n[7] Debugger ile degisken yazma\n"
set variable g_tick_count = 4242
print g_tick_count

printf "\n[8] SMOKE-OK\n"
kill
