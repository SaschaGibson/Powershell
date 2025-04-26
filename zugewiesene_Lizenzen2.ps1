# 1. TLS auf 1.2 zwingen
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Ensure-MicrosoftGraphModule {
    param([string]$ModuleName="Microsoft.Graph")
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Host "$ModuleName wird installiert..." -ForegroundColor Yellow
        # PSGallery vertrauen und ohne Rückfrage installieren
        if ((Get-PSRepository -Name PSGallery).InstallationPolicy -ne 'Trusted') {
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        }
        Install-Module -Name $ModuleName -Scope CurrentUser -Force -AllowClobber -Confirm:$false -ErrorAction Stop
        Write-Host "$ModuleName erfolgreich installiert." -ForegroundColor Green
    } else {
        Write-Host "$ModuleName ist bereits installiert." -ForegroundColor Green
    }
}

Ensure-MicrosoftGraphModule

Import-Module Microsoft.Graph -ErrorAction Stop
Write-Host "Microsoft.Graph Modul erfolgreich importiert." -ForegroundColor Green

Write-Host "=== Vor Connect-MgGraph ===" -ForegroundColor Cyan
# hier Device-Flow oder -Interactive wählen, je nach Bedarf
Connect-MgGraph -Scopes "User.Read.All","Directory.Read.All" -UseDeviceAuthentication -ErrorAction Stop
Write-Host "=== Nach Connect-MgGraph ===" -ForegroundColor Cyan

# UPN abfragen
$userUPN = Read-Host "Bitte geben Sie den User Principal Name (UPN) des Benutzers ein"

# Rest wie gehabt …
$user = Get-MgUser -UserId $userUPN -ErrorAction Stop
# …
Disconnect-MgGraph
Write-Host "Fertig!" -ForegroundColor Green
