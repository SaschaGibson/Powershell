# Module prüfen und ggf. aktualisieren


$moduleNames = @("Microsoft.Online.SharePoint.PowerShell", "SharePointPnPPowerShellOnline") # Fügen Sie die Namen der Module hinzu

foreach ($moduleName in $moduleNames) {
    # Prüfen, ob das Modul bereits installiert ist
    $installedModule = Get-InstalledModule -Name $moduleName -ErrorAction SilentlyContinue

    # Suchen nach der neuesten Version des Moduls im Repository
    $latestModule = Find-Module -Name $moduleName

    if ($installedModule -and $latestModule) {
        # Vergleichen der Versionen
        if ($installedModule.Version -lt $latestModule.Version) {
            # Installieren der neuesten Version, wenn die installierte Version älter ist
            Install-Module -Name $moduleName -Force -Scope CurrentUser
            Write-Host "Modul $moduleName aktualisiert auf Version $($latestModule.Version)"
        } else {
            Write-Host "Die aktuellste Version von $moduleName ($($installedModule.Version)) ist bereits installiert."
        }
    } elseif ($latestModule) {
        # Installieren des Moduls, wenn es noch nicht installiert ist
        Install-Module -Name $moduleName -Scope CurrentUser
        Write-Host "Modul $moduleName installiert in Version $($latestModule.Version)"
    } else {
        Write-Host "Modul $moduleName konnte nicht gefunden werden."
    }
}

# Ende Module prüfen



# Benutzeranmeldeinformationen
$User = "sascha.gibson@beta-hilfen.de"
$Password = ConvertTo-SecureString "BHE2020sg" -AsPlainText -Force
$Creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $Password

# Konfiguration
$timeoutInMilliSeconds = 43200000 # 12 Stunden in Millisekunden
$siteUrl = "https://betahilfen.sharepoint.com" # Ersetzen Sie dies durch Ihre SharePoint-Site-URL
$relativeUrl = "sites/TEAM-BETA" # Der relative Pfad zur Bibliothek

# Verbindungsaufbau
Connect-PnPOnline -Url $siteUrl -Credentials $Creds -RequestTimeout $timeoutInMilliSeconds

# Datei hinzufügen
try {
    Add-PnPFile -Path "C:\Tools\test.pdf" -Folder $relativeUrl
} catch {
    Write-Host "Fehler: $_"
}


