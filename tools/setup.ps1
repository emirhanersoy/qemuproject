<#
    setup.ps1  --  Gelistirme ortamini sifirdan kurar.
    -----------------------------------------------------------------
    Yeni bir makinede tek komutla ayni ortami elde etmek icin:

        powershell -ExecutionPolicy Bypass -File tools\setup.ps1

    Yaptiklari:
      1) QEMU kurar            (winget, RISC-V dahil tum hedefler)
      2) xpm kurar             (npm; Node.js gerekli)
      3) riscv-none-elf-gcc    (xPack GNU RISC-V Embedded GCC + GDB)
      4) config.mk uretir      (Makefile'in kullandigi arac yollari)
      5) Yollari kullanici PATH'ine ekler

    Yonetici yetkisi gerekmez; her sey kullanici kapsaminda kurulur.
#>
param(
    [switch] $SkipInstall   # sadece config.mk uret ve PATH ayarla
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

function Step($n, $msg) { Write-Host "`n[$n] $msg" -ForegroundColor Cyan }

# ---------------------------------------------------------------- 1
if (-not $SkipInstall) {
    Step 1 "QEMU kuruluyor (winget)..."
    $qemuExe = "C:\Program Files\qemu\qemu-system-riscv32.exe"
    if (Test-Path $qemuExe) {
        Write-Host "    zaten kurulu, atlaniyor."
    } else {
        winget install --id SoftwareFreedomConservancy.QEMU `
            --accept-package-agreements --accept-source-agreements --disable-interactivity
    }

    # ------------------------------------------------------------ 2
    Step 2 "xpm (xPack paket yoneticisi) kuruluyor..."
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        throw "Node.js bulunamadi. https://nodejs.org adresinden kurup tekrar deneyin."
    }
    npm install -g xpm@latest

    # ------------------------------------------------------------ 3
    Step 3 "RISC-V capraz derleyici (riscv-none-elf-gcc) kuruluyor..."
    Write-Host "    ~500 MB indirme, birkac dakika surebilir."
    xpm install --global @xpack-dev-tools/riscv-none-elf-gcc@latest
}

# ---------------------------------------------------------------- 4
Step 4 "Arac yollari bulunuyor ve config.mk uretiliyor..."

$gccCandidates = Get-ChildItem `
    "$env:APPDATA\xPacks\@xpack-dev-tools\riscv-none-elf-gcc\*\.content\bin\riscv-none-elf-gcc.exe" `
    -ErrorAction SilentlyContinue | Sort-Object FullName -Descending
if (-not $gccCandidates) {
    throw "riscv-none-elf-gcc bulunamadi. 3. adim basarisiz olmus olabilir."
}
$tcBin = $gccCandidates[0].Directory.FullName

$qemuExe = "C:\Program Files\qemu\qemu-system-riscv32.exe"
if (-not (Test-Path $qemuExe)) {
    $found = Get-Command qemu-system-riscv32 -ErrorAction SilentlyContinue
    if ($found) { $qemuExe = $found.Source } else { throw "qemu-system-riscv32 bulunamadi." }
}
$qemuBin = Split-Path $qemuExe -Parent

@"
# ---------------------------------------------------------------------
#  config.mk  --  BU MAKINEYE OZGU arac yollari.
#  tools\setup.ps1 tarafindan uretildi; git'e commit EDILMEZ.
# ---------------------------------------------------------------------
CROSS := $tcBin\riscv-none-elf-
QEMU  := $qemuExe
"@ | Out-File -FilePath (Join-Path $root "config.mk") -Encoding ascii

Write-Host "    CROSS := $tcBin\riscv-none-elf-"
Write-Host "    QEMU  := $qemuExe"

# ---------------------------------------------------------------- 4b
# launch.json ve c_cpp_properties.json toolchain surumunu yolun icinde
# tasiyor. Derleyici guncellenince F5 "Unable to start debugging" vermesin
# diye surumu burada kurulu olanla esitliyoruz.
Step "4b" "VSCode dosyalarindaki toolchain surumu guncelleniyor..."
$tcVer = $gccCandidates[0].Directory.Parent.Parent.Name   # orn. 15.2.0-1.1
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
foreach ($f in @(".vscode\launch.json", ".vscode\c_cpp_properties.json")) {
    $p = Join-Path $root $f
    if (-not (Test-Path $p)) { continue }
    $old = [System.IO.File]::ReadAllText($p)
    $new = $old -replace 'riscv-none-elf-gcc/[^/]+/\.content', "riscv-none-elf-gcc/$tcVer/.content"
    if ($new -ne $old) {
        [System.IO.File]::WriteAllText($p, $new, $utf8NoBom)
        Write-Host "    guncellendi: $f -> $tcVer"
    } else {
        Write-Host "    zaten guncel: $f ($tcVer)"
    }
}

# ---------------------------------------------------------------- 5
Step 5 "Kullanici PATH'i guncelleniyor..."
$userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
if (-not $userPath) { $userPath = '' }
$added = @()
foreach ($d in @($tcBin, $qemuBin)) {
    if (($userPath -split ';') -notcontains $d) {
        $userPath = ($userPath.TrimEnd(';') + ';' + $d).TrimStart(';')
        $added += $d
    }
}
if ($added.Count -gt 0) {
    [Environment]::SetEnvironmentVariable('PATH', $userPath, 'User')
    $added | ForEach-Object { Write-Host "    eklendi: $_" }
    Write-Host "    NOT: yeni PATH icin VSCode/terminal yeniden baslatilmali." -ForegroundColor Yellow
} else {
    Write-Host "    zaten ekli."
}

# ---------------------------------------------------------------- 6
Step 6 "Surum kontrolu"
& "$tcBin\riscv-none-elf-gcc.exe" --version | Select-Object -First 1
& "$tcBin\riscv-none-elf-gdb.exe" --version | Select-Object -First 1
& $qemuExe --version | Select-Object -First 1

Write-Host "`nKurulum tamam. Simdi: mingw32-make  ve  mingw32-make run" -ForegroundColor Green
