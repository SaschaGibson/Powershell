<# GraphLicenseScript.ps1
Skript zum Abrufen von Microsoft Graph-Lizenzdetails für einen oder mehrere Benutzer.
Supports:
 - Certificate-based auth (unattended)
 - Client-secret auth (unattended)
 - Device code flow auth (interactive, cached)
#>

param(
    [string]$ClientId             = '',
    [string]$TenantId             = '',
    [string]$CertificateThumbprint= '',
    [string]$ClientSecret         = ''
)

# Marker: Script Start
Write-Host "=== Script Start ===" -ForegroundColor Magenta

# 1. TLS 1.2 erzwingen
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 2. Funktion zum sicheren Installieren eines PowerShell-Moduls
function Ensure-Module {
    param([string]$ModuleName)
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Host "Installiere Modul $ModuleName..." -ForegroundColor Yellow
        if ((Get-PSRepository -Name PSGallery).InstallationPolicy -ne 'Trusted') {
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
        }
        Install-Module -Name $ModuleName -Scope CurrentUser -Force -AllowClobber -Confirm:$false -ErrorAction Stop
        Write-Host "Modul $ModuleName installiert." -ForegroundColor Green
    }
}

# 3. Submodule sicherstellen und importieren
$modules = 'Microsoft.Graph.Authentication','Microsoft.Graph.Users'
foreach ($mod in $modules) {
    Ensure-Module -ModuleName $mod
    Write-Host "Importiere Modul $mod..." -ForegroundColor Cyan
    Import-Module $mod -ErrorAction Stop
}

# 4. Authentifizierung mit MSAL-Cache
Write-Host "=== Authentifiziere: Prüfe MSAL-Cache ===" -ForegroundColor Cyan
$cachePath = Join-Path $env:LOCALAPPDATA 'Microsoft\MSAL.PS\msal.cache'

if (Test-Path $cachePath) {
    Write-Host "=== MSAL-Cache gefunden: $cachePath ===" -ForegroundColor Green
    Connect-MgGraph -ErrorAction Stop
    Write-Host "=== Authentifizierung aus Cache erfolgreich ===`n" -ForegroundColor Green
} else {
    Write-Host "=== Kein Cache vorhanden, starte Device Code Flow ===" -ForegroundColor Yellow
    Connect-MgGraph -Scopes 'User.Read.All','Directory.Read.All' -UseDeviceAuthentication -ErrorAction Stop
    Write-Host "=== Device Code Auth erfolgreich. MSAL-Cache wird angelegt. ===`n" -ForegroundColor Green
}

# 5. UPN/Eingabe mit Wildcards
Write-Host "=== Vor UPN-Eingabe (z.B. 'user@domain.com' oder '*@domain.com') ===" -ForegroundColor Cyan
$userPattern = Read-Host "Bitte UPN oder Muster eingeben"
$userPattern = $userPattern.Trim()

# 6. Wildcard → OData-Filter
function Convert-WildcardToFilter {
    param([string]$pattern)
    switch -Regex ($pattern) {
        '^\*(.+)\*$' { return "contains(userPrincipalName,'$($Matches[1])')" }
        '^(.+)\*$'    { return "startswith(userPrincipalName,'$($Matches[1])')" }
        '^\*(.+)'     { return "endswith(userPrincipalName,'$($Matches[1])')" }
        default       { return "userPrincipalName eq '$pattern'" }
    }
}
$filter = Convert-WildcardToFilter -pattern $userPattern
Write-Host "=== OData-Filter: $filter ===`n" -ForegroundColor DarkGray

# 7. Benutzer abrufen
Write-Host "=== Suche Benutzer mit Filter ===" -ForegroundColor Cyan
$users = Get-MgUser -Filter $filter -All -ErrorAction Stop
if ($users.Count -eq 0) {
    Write-Host "Keine Benutzer gefunden." -ForegroundColor Yellow
    exit 0
}

# 8. Lizenzdetails abrufen und ausgeben
foreach ($u in $users) {
    Write-Host "*** Lizenzdetails für $($u.UserPrincipalName) (Id: $($u.Id)) ***" -ForegroundColor Cyan
    $licenses = Get-MgUserLicenseDetail -UserId $u.Id -ErrorAction Stop
    if ($licenses.Count -gt 0) {
        $licenses | Select-Object Id,SkuId,SkuPartNumber | Format-Table -AutoSize
    } else {
        Write-Host "Keine Lizenzen zugewiesen." -ForegroundColor Yellow
    }
    Write-Host "`n"
}

# 9. Verbindung trennen
Disconnect-MgGraph -ErrorAction SilentlyContinue
Write-Host "=== Script Ende ===" -ForegroundColor Magenta
