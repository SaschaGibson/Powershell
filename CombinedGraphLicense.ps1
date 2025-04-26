<#
zugewiesene Lizenzen mit Namen.ps1

Persistente Delegated-Authentifizierung (PS7) und Lizenz-Abruf via Microsoft Graph
mit sprechenden Produktnamen und dynamischer Anpassung an neue SKUs.

Voraussetzungen:
 - PowerShell 7
 - Az.Accounts Modul
 - Microsoft.Graph.Authentication Modul
 - Microsoft.Graph.Users Modul

Parameter (optional):
 - TenantId: GUID des Azure-Tenants (Standard: aus aktuellem Az-Kontext)
 - Scopes: Array von Graph-Scopes (Standard: User.Read.All, Directory.Read.All)

Ablauf:
 1. TLS 1.2 erzwingen
 2. Module installieren/importieren
 3. TenantId-Fallback
 4. Authentifizierung (Silent, Browser, Device-Code)
 5. SKU-Mapping dynamisch mit Friendly-Namen
 6. UPN/Muster-Abfrage mit Wildcards/Validierung
 7. Benutzer suchen & Lizenzdetails ausgeben
 8. Connection trennen
#>

param(
    [string]   $TenantId = '',
    [string[]] $Scopes   = @('User.Read.All','Directory.Read.All')
)

# 1) TLS 1.2 sicherstellen
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 2) Module prüfen/installieren
function Ensure-Module { param([string]$Name)
    if (-not (Get-Module -ListAvailable -Name $Name)) {
        Write-Host "Installiere Modul $Name..." -ForegroundColor Yellow
        Install-Module -Name $Name -Scope CurrentUser -Force -AllowClobber
    }
    Import-Module $Name -ErrorAction Stop
}
foreach ($m in 'Az.Accounts','Microsoft.Graph.Authentication','Microsoft.Graph.Users') {
    Ensure-Module $m
}

# 3) TenantId aus Az-Kontext (Fallback)
if (-not $TenantId -or $TenantId -notmatch '^[0-9a-fA-F\-]{36}$') {
    try {
        $ctx      = Get-AzContext -ErrorAction Stop
        $TenantId = $ctx.Tenant.Id
        Write-Host "Verwende TenantId aus aktuellem Az-Kontext: $TenantId" -ForegroundColor Yellow
    } catch {
        Write-Host "Warnung: Kein Az-Kontext gefunden; Device-Code-Flow ohne Tenant-Parameter." -ForegroundColor Yellow
        $TenantId = ''
    }
}

# 4) Authentifizierungs-Routine
function Authenticate-Graph {
    param($TenantId, $Scopes)

    # Silent-Login via Az-Cache
    Write-Host "=== Silent-Login via Az-Cache ===" -ForegroundColor Cyan
    try {
        $info = Get-AzAccessToken -ResourceUrl 'https://graph.microsoft.com' -AsSecureString -ErrorAction Stop
        if ($info.ExpiresOn -lt (Get-Date)) { throw "Token abgelaufen" }
        Write-Host "Silent-Token gültig bis $($info.ExpiresOn)" -ForegroundColor Green
        Connect-MgGraph -AccessToken $info.Token -ErrorAction Stop
        Write-Host "Verbunden via Az-Token als $((Get-MgContext).Account)" -ForegroundColor Green
        return
    } catch {
        Write-Host "Silent-Login fehlgeschlagen: $_" -ForegroundColor Yellow
    }

    # Browser-Login (falls TenantId vorhanden)
    Write-Host "=== Browser-Login via Connect-AzAccount ===" -ForegroundColor Cyan
    $loginArgs = @{ ErrorAction = 'Stop' }
    if ($TenantId) { $loginArgs['Tenant'] = $TenantId }
    try {
        Connect-AzAccount @loginArgs | Out-Null
        Write-Host "Connect-AzAccount erfolgreich." -ForegroundColor Green
        $info = Get-AzAccessToken -ResourceUrl 'https://graph.microsoft.com' -AsSecureString -ErrorAction Stop
        Connect-MgGraph -AccessToken $info.Token -ErrorAction Stop
        Write-Host "Verbunden via Az-Token als $((Get-MgContext).Account)" -ForegroundColor Green
        return
    } catch {
        Write-Host "Connect-AzAccount fehlgeschlagen: $_" -ForegroundColor Red
    }

    # Device-Code-Flow direkt via Graph-SDK
    Write-Host "=== Device-Code-Flow direkt via Connect-MgGraph ===" -ForegroundColor Cyan
    Connect-MgGraph -Scopes $Scopes -UseDeviceAuthentication -TenantId $TenantId -ErrorAction Stop
    Write-Host "Connected via Device-Code direkt als $((Get-MgContext).Account)" -ForegroundColor Green
}
Authenticate-Graph -TenantId $TenantId -Scopes $Scopes

# 5) Dynamisches SKU-Mapping mit Friendly-Namen
Write-Host "Ermittle alle verfügbaren SKUs..." -ForegroundColor Cyan
$allSkus = Get-MgSubscribedSku -All -ErrorAction Stop |
    Select-Object -ExpandProperty SkuPartNumber |
    Sort-Object -Unique

# Default Friendly: replace underscores with spaces
$SkuFriendlyNames = @{}
foreach ($sku in $allSkus) {
    $SkuFriendlyNames[$sku] = $sku -replace '_',' '
}
# Manuelle Overrides
$SkuFriendlyNames['AAD_PREMIUM_P2']                                = 'Azure AD Premium P2'
$SkuFriendlyNames['Microsoft_Teams_EEA_New']                       = 'Microsoft Teams (EEA)'
$SkuFriendlyNames['Microsoft_Teams_Audio_Conferencing_select_dial_out'] = 'Audio Conferencing Dial-Out'
$SkuFriendlyNames['INTUNE_A']                                      = 'Microsoft Intune'
$SkuFriendlyNames['ENTERPRISEPACK']                                = 'Office 365 E3'
$SkuFriendlyNames['FLOW_FREE']                                     = 'Power Automate (Free)'
$SkuFriendlyNames['O365_BUSINESS_PREMIUM']                         = 'Microsoft 365 Business Premium'
$SkuFriendlyNames['O365_BUSINESS_ESSENTIALS']                      = 'Microsoft 365 Business Basic'
$SkuFriendlyNames['Office_365_w/o_Teams_Bundle_Business_Premium']  = 'Office 365 Business Premium (ohne Teams)'

# 6) UPN/Muster-Abfrage mit Wildcards & Validierung
Write-Host "Bitte UPN/Muster ('user@domain.com','*@domain.com' oder '*'):" -ForegroundColor Cyan
$userPattern = (Read-Host).Trim()
if (-not $userPattern) { Write-Host "ERROR: Keine Eingabe." -ForegroundColor Red; exit 1 }
$emailRx = '^[^@\s]+@[^@\s]+\.[^@\s]+$'
if ($userPattern -eq '*') {
    $filter = '' ; Write-Host "Alle Benutzer werden abgefragt." -ForegroundColor Yellow
} elseif ($userPattern -match '\*') {
    switch -Regex ($userPattern) {
        '^\*(.+)\*$' { $filter = "contains(userPrincipalName,'$($Matches[1])')" }
        '^(.+)\*$'    { $filter = "startswith(userPrincipalName,'$($Matches[1])')" }
        '^\*(.+)'     { $filter = "endswith(userPrincipalName,'$($Matches[1])')" }
        default       { Write-Host "ERROR: Ungültiges Wildcard-Format." -ForegroundColor Red; exit 1 }
    }
    Write-Host "Wildcard-Filter: $filter" -ForegroundColor DarkGray
} elseif ($userPattern -match $emailRx) {
    $filter = "userPrincipalName eq '$userPattern'"; Write-Host "Exact-Filter: $filter" -ForegroundColor DarkGray
} else {
    Write-Host "ERROR: Ungültiges Format." -ForegroundColor Red; exit 1
}

# 7) Benutzer suchen & Lizenzdetails ausgeben
Write-Host "Suche Benutzer..." -ForegroundColor Cyan
$users = if ($filter) { Get-MgUser -Filter $filter -All -ErrorAction Stop } else { Get-MgUser -All -ErrorAction Stop }
if ($users.Count -eq 0) { Write-Host "Keine Benutzer gefunden." -ForegroundColor Yellow; Disconnect-MgGraph; exit 0 }
Write-Host "$($users.Count) Benutzer gefunden." -ForegroundColor Green

foreach ($u in $users) {
    Write-Host "*** Lizenzen für $($u.UserPrincipalName) ***" -ForegroundColor Cyan
    $licenses = Get-MgUserLicenseDetail -UserId $u.Id -ErrorAction Stop
    $licenses | ForEach-Object {
        [PSCustomObject]@{
            ProductName   = $SkuFriendlyNames[$_.SkuPartNumber]
            SkuPartNumber = $_.SkuPartNumber
            Id            = $_.Id
        }
    } | Format-Table ProductName,SkuPartNumber,Id -AutoSize
    Write-Host "`n"
}

# 8) Connection trennen
Disconnect-MgGraph -ErrorAction SilentlyContinue
Write-Host "=== Script Ende ===" -ForegroundColor Magenta
