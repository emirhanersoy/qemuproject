<#
    qemu-stop.ps1
    -------------
    Calisan QEMU orneklerini kapatir. launch.json icinde postDebugTask
    olarak cagrilir: debug oturumu bitince arkada QEMU kalmasin.
#>
$procs = Get-Process -Name "qemu-system-riscv32" -ErrorAction SilentlyContinue
if ($procs) {
    $procs | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Host "[qemu-stop] $($procs.Count) QEMU ornegi kapatildi."
} else {
    Write-Host "[qemu-stop] calisan QEMU yok."
}
