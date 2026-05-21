# ==============================================================================
# enable_share.ps1 — Compartilha internet via ICS (Internet Connection Sharing)
# Executar como Administrador.
#
# O ICS seta automaticamente o IP 192.168.137.1 no Windows e fornece
# DHCP para o servidor — sem precisar configurar IP manualmente no servidor.
# ==============================================================================

# ── Variáveis ──────────────────────────────────────────────────────────────────
$IFACE_EXT = "Ethernet"      # USB (ASIX) — internet
$IFACE_INT = "Ethernet 2"    # Killer E2600 — cabo direto pro servidor
# ──────────────────────────────────────────────────────────────────────────────

# Verifica privilégios de Administrador
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-NOT $isAdmin) {
    Write-Error "Execute este script como Administrador."
    exit 1
}

Write-Host "Configurando Internet Connection Sharing (ICS)..." -ForegroundColor Cyan

# Cria objeto COM do ICS
$netShare = New-Object -ComObject HNetCfg.HNetShare

# Lista todas as conexoes
$connections = @($netShare.EnumEveryConnection)

# Encontra as interfaces pelo nome
$extConn = $null
$intConn = $null
foreach ($conn in $connections) {
    $props = $netShare.NetConnectionProps.Invoke($conn)
    if ($props.Name -eq $IFACE_EXT) { $extConn = $conn }
    if ($props.Name -eq $IFACE_INT) { $intConn = $conn }
}

if (-not $extConn) {
    Write-Error "Interface externa '$IFACE_EXT' nao encontrada."
    Get-NetAdapter | Select-Object Name, Status | Format-Table
    exit 1
}
if (-not $intConn) {
    Write-Error "Interface interna '$IFACE_INT' nao encontrada."
    Get-NetAdapter | Select-Object Name, Status | Format-Table
    exit 1
}

# Desabilita ICS existente em todas as interfaces (evita conflito)
Write-Host "-> Limpando ICS existente..."
foreach ($conn in $connections) {
    $cfg = $netShare.INetSharingConfigurationForINetConnection.Invoke($conn)
    if ($cfg.SharingEnabled) { $cfg.DisableSharing() }
}

# Habilita ICS
$extConfig = $netShare.INetSharingConfigurationForINetConnection.Invoke($extConn)
$intConfig  = $netShare.INetSharingConfigurationForINetConnection.Invoke($intConn)

Write-Host "-> Ativando ICS: $IFACE_EXT (publico) -> $IFACE_INT (privado)..."
$extConfig.EnableSharing(0)   # 0 = lado publico (internet)
$intConfig.EnableSharing(1)   # 1 = lado privado (servidor)

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host " Sucesso! ICS ativado."
Write-Host " IP do Windows na Ethernet 2: 192.168.137.1"
Write-Host " Servidor recebera IP via DHCP automaticamente."
Write-Host ""
Write-Host " Aguarde ~15 segundos para o servidor"
Write-Host " obter o IP e entao rode:"
Write-Host ""
Write-Host "   arp -a"
Write-Host ""
Write-Host " Procure por entradas em 192.168.137.x"
Write-Host " Esse sera o IP do servidor para o SSH."
Write-Host "=========================================="
