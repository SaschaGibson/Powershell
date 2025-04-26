# Test.ps1

# 1. TLS sicherstellen
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 2. Az.Accounts laden/installieren
if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
    Install-Module Az.Accounts -Scope CurrentUser -Force
}
Import-Module Az.Accounts

# 3. Einmaliges Browser-Login (falls nötig)
if (-not (Get-AzContext -ErrorAction SilentlyContinue)) {
    Connect-AzAccount
}

# 4. Token holen und in SecureString konvertieren
$azToken = Get-AzAccessToken -ResourceUrl 'https://graph.microsoft.com'
$secureToken = ConvertTo-SecureString -String $azToken.Token -AsPlainText -Force

# 5. Graph-Modul laden/installieren
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force
}
Import-Module Microsoft.Graph.Authentication

# 6. Mit Graph verbinden
Connect-MgGraph -AccessToken $secureToken -ErrorAction Stop
Write-Host "=== Mit Graph verbunden als $((Get-MgContext).Account) ===" -ForegroundColor Green

# 7. Test-Call
Get-MgUser -UserId me | Select-Object DisplayName, UserPrincipalName | Format-List
