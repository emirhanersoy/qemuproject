<#
    smoke-test.ps1  --  Ucdan uca otomatik dogrulama.
    -----------------------------------------------------------------
        powershell -ExecutionPolicy Bypass -File tools\smoke-test.ps1

    Kontrol ettigi 3 sey:
      A) Proje derleniyor mu?
      B) QEMU'da calisip UART'a dogru ciktiyi basiyor mu?
         (Hello World + zamanlayici tick'leri gercek zamanla uyumlu mu?)
      C) GDB ile baglanip breakpoint koyup kesmeyi yakalayabiliyor muyuz?

    Cikis kodu 0 = hepsi gecti. Boylece CI/CD'ye baglanabilir.
#>
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

# Harici program stderr'e yazinca PowerShell 5.1 bunu hataya cevirip
# betigi durdurur; bu yuzden Stop kullanmiyoruz.
$ErrorActionPreference = 'Continue'

$results = [ordered]@{}
function Check($name, [bool]$ok, $note = "") {
    $results[$name] = $ok
    $tag = if ($ok) { "GECTI    " } else { "BASARISIZ" }
    $col = if ($ok) { "Green" } else { "Red" }
    Write-Host ("  [{0}] {1}  {2}" -f $tag, $name, $note) -ForegroundColor $col
}

# Harici araci calistirip stdout+stderr'i tek metin olarak dondurur.
# (Start-Process + yonlendirme, PowerShell'in stderr sarmalamasini atlatir.)
function Invoke-Tool($exe, [string[]] $argv) {
    $o = [System.IO.Path]::GetTempFileName()
    $e = [System.IO.Path]::GetTempFileName()
    Start-Process -FilePath $exe -ArgumentList $argv -NoNewWindow -Wait `
        -WorkingDirectory $root -RedirectStandardOutput $o -RedirectStandardError $e | Out-Null
    $txt = (Get-Content $o -Raw) + (Get-Content $e -Raw)
    Remove-Item $o, $e -Force -ErrorAction SilentlyContinue
    return $txt
}

# --- Arac yollarini config.mk'dan oku (Makefile ile ayni kaynak) ---
$qemu = "qemu-system-riscv32"
$gdb  = "riscv-none-elf-gdb"
if (Test-Path "config.mk") {
    foreach ($l in Get-Content "config.mk") {
        if ($l -match '^\s*QEMU\s*:?=\s*(.+?)\s*$')  { $qemu = $Matches[1] }
        if ($l -match '^\s*CROSS\s*:?=\s*(.+?)\s*$') { $gdb  = $Matches[1] + "gdb.exe" }
    }
}
$make = if ($env:OS -eq 'Windows_NT') { "mingw32-make" } else { "make" }

# =================================================================== A
Write-Host "`n=== A) Derleme ===" -ForegroundColor Cyan
Invoke-Tool $make @('clean') | Out-Null
$buildLog = Invoke-Tool $make @('all')
Write-Host $buildLog -ForegroundColor DarkGray
Check "derleme" (Test-Path "firmware.elf") "firmware.elf uretildi"

# =================================================================== B
Write-Host "`n=== B) QEMU'da calistirma (UART ciktisi) ===" -ForegroundColor Cyan
$outFile = Join-Path $root "qemu-out.txt"
if (Test-Path $outFile) { Remove-Item $outFile -Force }

Get-Process -Name "qemu-system-riscv32" -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue

$p = Start-Process -FilePath $qemu -PassThru -WindowStyle Hidden -WorkingDirectory $root -ArgumentList @(
    '-machine','virt','-cpu','rv32','-smp','1','-m','128M',
    '-display','none','-serial',"file:$outFile",
    '-bios','none','-kernel','firmware.elf'
)
Start-Sleep -Seconds 5
if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force }

$uart = if (Test-Path $outFile) { Get-Content $outFile -Raw } else { "" }
Write-Host $uart -ForegroundColor DarkGray

Check "hello-world"   ($uart -match 'Hello, World!')  "UART'a banner basildi"
Check "platform-adi"  ($uart -match 'QEMU riscv32')   "platform.h degerleri dogru"
Check "timer-kesmesi" ($uart -match '\[tick 10\]')    "ilk saniyenin tick'i geldi"

# 5 saniye calistik. Son tick 30..50 arasinda olmali; bu, mtime frekansinin
# dogru oldugunu (yani simule zamanin gercek zamanla uyustugunu) gosterir.
$lastTick = 0
foreach ($m in [regex]::Matches($uart, '\[tick (\d+)\]')) { $lastTick = [int]$m.Groups[1].Value }
Check "zaman-dogrulugu" ($lastTick -ge 30 -and $lastTick -le 50) "son tick = $lastTick (beklenen 30..50)"

# =================================================================== C
Write-Host "`n=== C) GDB ile hata ayiklama zinciri ===" -ForegroundColor Cyan
# qemu-debug.ps1'i AYRI surec olarak DEGIL, bu oturumda cagiriyoruz.
# Ayri surec + cikti yonlendirmesi yapilirsa QEMU acik kaldigi surece
# Start-Process -Wait akislarin kapanmasini bekleyip kilitlenir.
try {
    & "$root\tools\qemu-debug.ps1" | Out-Null
    $serverUp = $true
} catch {
    Write-Host "  qemu-debug.ps1 hatasi: $_" -ForegroundColor Red
    $serverUp = $false
}
$gdbLog = if ($serverUp) { Invoke-Tool $gdb @('firmware.elf','-batch','-x',"$root\tools\smoke.gdb") } else { "" }
Write-Host $gdbLog -ForegroundColor DarkGray
& "$root\tools\qemu-stop.ps1" | Out-Null

Check "gdb-baglanti"   ($gdbLog -match 'Breakpoint 1, main')      "main'de breakpoint tutuldu"
Check "mtvec-kurulumu" ($gdbLog -match 'mtvec\s+=\s+0x8000')      "kesme vektoru RAM'de kurulu"
Check "timer-irq"      ($gdbLog -match 'mcause\s+=\s+0x80000007') "mcause = machine timer irq"
Check "degisken-yazma" ($gdbLog -match '4242')                    "debugger degisken yazabiliyor"
Check "smoke-tamam"    ($gdbLog -match 'SMOKE-OK')                "gdb betigi sonuna kadar kostu"

# =================================================================== Ozet
$failed = @($results.Keys | Where-Object { -not $results[$_] })
Write-Host "`n=== OZET ===" -ForegroundColor Cyan
Write-Host ("  {0} / {1} kontrol gecti" -f ($results.Count - $failed.Count), $results.Count)
if ($failed.Count -gt 0) {
    Write-Host ("  BASARISIZ: " + ($failed -join ", ")) -ForegroundColor Red
    exit 1
}
Write-Host "  TUM KONTROLLER GECTI" -ForegroundColor Green
exit 0
