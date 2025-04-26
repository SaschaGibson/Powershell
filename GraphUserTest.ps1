<# GraphUserTest.ps1
Testskript zur Verifizierung der Microsoft.Graph.Users-Module-Funktionalität
Verwendet den angelegten MSAL-Cache und Context, um einen Beispiel-User abzurufen.
#>

param(
    [string]$ContextFile = "$env:USERPROFILE\GraphAuthContext.json",
    [string]$TestUPN     = ''   # z.B. 'tanja.herbst@beta-hilfen.de'
)

# 1. TLS 1.2 erzwingen
Write-Host "=== TLS 1.2 erzwingen ===" -ForegroundColor Cyan
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 2. MSAL-Cache und Auth-Context laden
$cachePath = Join-Path $env:LOCALAPPDATA 'Microsoft\MSAL.PS\msal.cache'
Write-Host "=== CachePath: $cachePath ===" -ForegroundColor DarkGray
if (-not (Test-Path $cachePath)) {
    Write-Host "MSAL-Cache nicht gefunden. Bitte zuerst GraphAuthTest.ps1 ausführen." -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $ContextFile)) {
    Write-Host "Context-Datei $ContextFile nicht gefunden. Bitte GraphAuthTest.ps1 ausführen." -ForegroundColor Red
    exit 1
}

# 3. Authentication: Silent login
Write-Host "=== Silent-Login via MSAL-Cache ===" -ForegroundColor Cyan
Connect-MgGraph -ErrorAction Stop
Write-Host "=== Authentifizierung OK: $((Get-MgContext).Account) ===`n" -ForegroundColor Green

# 4. Test-User abrufen
if (-not $TestUPN) {
    $TestUPN = (Get-Content $ContextFile | ConvertFrom-Json).Account
    Write-Host "Kein TestUPN übergeben, verwende aktuellen Account: $TestUPN" -ForegroundColor Yellow
}
Write-Host "=== Hole User-Objekt für $TestUPN ===" -ForegroundColor Cyan
try {
    $user = Get-MgUser -UserId $TestUPN -ErrorAction Stop -Verbose
    Write-Host "User abgerufen: DisplayName=$($user.DisplayName), Mail=$($user.Mail)" -ForegroundColor Green
} catch {
    Write-Host "FEHLER: Get-MgUser schlägt fehl: $_" -ForegroundColor Red
}

Write-Host "=== GraphUserTest abgeschlossen ===" -ForegroundColor Magenta
