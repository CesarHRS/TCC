# ==============================================================================
# disable_share.ps1 — Desativa o ICS e limpa a configuracao de rede
# Executar como Administrador.
# ==============================================================================

# Verifica privilégios de Administrador
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-NOT $isAdmin) {
    Write-Error "Execute este script como Administrador."
    exit 1
}

Write-Host "Desativando Internet Connection Sharing (ICS)..." -ForegroundColor Cyan

$netShare = New-Object -ComObject HNetCfg.HNetShare
$connections = @($netShare.EnumEveryConnection)

$found = $false
foreach ($conn in $connections) {
    $cfg = $netShare.INetSharingConfigurationForINetConnection.Invoke($conn)
    if ($cfg.SharingEnabled) {
        $name = $netShare.NetConnectionProps.Invoke($conn).Name
        Write-Host "-> Desabilitando ICS em '$name'..."
        $cfg.DisableSharing()
        $found = $true
    }
}

if (-not $found) { Write-Host "-> Nenhum ICS ativo encontrado." }

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host " Pronto! ICS desativado."
Write-Host "=========================================="
