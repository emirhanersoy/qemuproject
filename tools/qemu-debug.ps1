<#
    qemu-debug.ps1
    --------------
    QEMU'yu "GDB sunucusu acik + islemci durdurulmus" halde baslatir.

    VSCode bunu launch.json icindeki preLaunchTask olarak cagirir.
    Betik QEMU'yu AYRI bir konsol penceresinde baslatip hemen doner;
    boylece VSCode task'i tamamlanmis sayar ve GDB baglanmaya gecer.
    UART ciktisi o ayri pencerede gorunur.

    QEMU parametreleri:
      -s  : localhost:1234'te GDB sunucusu ac  (= -gdb tcp::1234)
      -S  : ilk komutu CALISTIRMA, durdurulmus basla
#>
param(
    [string] $Elf        = "firmware.elf",
    [int]    $Port       = 1234,
    [int]    $TimeoutSec = 15,
    # -Foreground: VSCode F5 icin. QEMU bu terminalde calisir (UART ciktisi
    # VSCode'un terminal panelinde gorunur) ve betik QEMU kapanana kadar
    # DONMEZ. Neden: VSCode bitmis bir task'in terminalini kapatirken o
    # terminalden dogan tum surecleri, yani QEMU'yu da oldurur. Task acik
    # kalirsa QEMU da yasar; debug bitince postDebugTask (qemu-stop) kapatir.
    # Parametresiz cagri (smoke-test.ps1) eskisi gibi ayri pencere acip doner.
    [switch] $Foreground
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

# --- QEMU yolunu config.mk'dan oku (tek dogru kaynak) ---
$qemu = $null
if (Test-Path "config.mk") {
    foreach ($line in Get-Content "config.mk") {
        if ($line -match '^\s*QEMU\s*:?=\s*(.+?)\s*$') { $qemu = $Matches[1] }
    }
}
if (-not $qemu) { $qemu = "qemu-system-riscv32" }
if (-not (Get-Command $qemu -ErrorAction SilentlyContinue)) {
    throw "QEMU bulunamadi: '$qemu'. tools\setup.ps1 betigini calistirin."
}
if (-not (Test-Path $Elf)) {
    throw "$Elf yok. Once derleyin (mingw32-make)."
}

# --- Onceki QEMU orneklerini kapat: port 1234 mesgul kalmasin ---
Get-Process -Name "qemu-system-riscv32" -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue

$qemuArgs = @(
    '-machine', 'virt',
    '-cpu',     'rv32',
    '-smp',     '1',
    '-m',       '128M',
    '-display', 'none',
    '-serial',  'stdio',
    '-bios',    'none',
    '-kernel',  $Elf,
    '-gdb',     "tcp::$Port",
    '-S'
)

Write-Host "[qemu-debug] baslatiliyor: $qemu"
Write-Host "[qemu-debug] GDB sunucusu : localhost:$Port (islemci durdurulmus)"
if ($Foreground) {
    $proc = Start-Process -FilePath $qemu -ArgumentList $qemuArgs -WorkingDirectory $root -NoNewWindow -PassThru
} else {
    $proc = Start-Process -FilePath $qemu -ArgumentList $qemuArgs -WorkingDirectory $root -PassThru
}

# --- GDB baglanmadan once portun gercekten dinlemeye gectigini dogrula ---
#     (bu kontrol olmazsa klasik "connection refused" yarisi yasanir)
$deadline = (Get-Date).AddSeconds($TimeoutSec)
while ((Get-Date) -lt $deadline) {
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $client.Connect("127.0.0.1", $Port)
        $client.Close()
        # DIKKAT: bu satir tasks.json'daki "endsPattern" ile eslesiyor;
        # metni degistirirsen orayi da degistir, yoksa F5 sonsuza dek bekler.
        Write-Host "[qemu-debug] hazir, GDB baglanabilir."
        if ($Foreground) {
            Write-Host "[qemu-debug] UART ciktisi asagida. Debug bitince QEMU kapanir."
            $proc.WaitForExit()
        }
        exit 0
    } catch {
        Start-Sleep -Milliseconds 150
    } finally {
        $client.Dispose()
    }
}
throw "QEMU $TimeoutSec saniyede $Port portunu acmadi."
