# Funktion zur Überprüfung und Installation des Microsoft Graph PowerShell SDKs
function Ensure-MicrosoftGraphModule {
    param (
        [string]$ModuleName = "Microsoft.Graph"
    )
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Host "$ModuleName wird installiert..." -ForegroundColor Yellow
        try {
            Install-Module -Name $ModuleName -Scope CurrentUser -Force -AllowClobber
            Write-Host "$ModuleName erfolgreich installiert." -ForegroundColor Green
        } catch {
            Write-Host "Fehler bei der Installation von ${ModuleName}: $_" -ForegroundColor Red
            exit
        }
    } else {
        Write-Host "$ModuleName ist bereits installiert." -ForegroundColor Green
    }
}

# Sicherstellen, dass das Microsoft Graph Modul installiert ist
Ensure-MicrosoftGraphModule

# Importieren des Microsoft Graph Moduls
try {
    Import-Module Microsoft.Graph
    Write-Host "Microsoft.Graph Modul erfolgreich importiert." -ForegroundColor Green
} catch {
    Write-Host "Fehler beim Importieren des Microsoft.Graph Moduls: $_" -ForegroundColor Red
    exit
}

# Verbindung zu Microsoft Graph herstellen
try {
    Connect-MgGraph -Scopes "User.Read.All", "Directory.Read.All"
    Write-Host "Erfolgreich mit Microsoft Graph verbunden." -ForegroundColor Green
} catch {
    Write-Host "Fehler beim Herstellen der Verbindung zu Microsoft Graph: $_" -ForegroundColor Red
    exit
}

# Benutzer-UPN abfragen
$userUPN = Read-Host "Bitte geben Sie den User Principal Name (UPN) des Benutzers ein"

# Benutzerinformationen abrufen
try {
    $user = Get-MgUser -UserId $userUPN
    $userId = $user.Id
    Write-Host "Benutzer UPN: ${userUPN}" -ForegroundColor Green
} catch {
    Write-Host "Fehler beim Abrufen der Benutzerinformationen für ${userUPN}: $_" -ForegroundColor Red
    Disconnect-MgGraph
    exit
}

# Lizenzdetails des Benutzers abrufen
try {
    $licenses = Get-MgUserLicenseDetail -UserId $userId
    if ($licenses) {
        Write-Host "Zugewiesene Lizenzen für Benutzer ${userUPN}:" -ForegroundColor Cyan
        foreach ($license in $licenses) {
            Write-Host "License: $($license.SkuPartNumber)"
            foreach ($service in $license.ServicePlans) {
                Write-Host " Service: $($service.ServicePlanName) Status: $($service.ProvisioningStatus)"
            }
        }
    } else {
        Write-Host "Keine Lizenzen für Benutzer ${userUPN} gefunden." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Fehler beim Abrufen der Lizenzdetails für ${userUPN}: $_" -ForegroundColor Red
}

# Verbindung zu Microsoft Graph trennen
try {
    Disconnect-MgGraph
    Write-Host "Verbindung zu Microsoft Graph getrennt." -ForegroundColor Green
} catch {
    Write-Host "Fehler beim Trennen der Verbindung zu Microsoft Graph: $_" -ForegroundColor Red
}
