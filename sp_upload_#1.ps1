# Variablenkonfiguration
$User = "sascha.gibson@beta-hilfen.de" # Benutzername für SharePoint
$PasswordPlainText = "xxxxxx" # Passwort
$siteUrl = "https://betahilfen.sharepoint.com" # URL  SharePoint-Site
$relativeUrl = "/sites/TEAM-BETA/Freigegebene Dokumente/Forms" # Relativer Pfad zur Bibliothek
$localFolderPath = "C:\Tools\test" # Lokaler Ordnerpfad
$maxRetryCount = 3 # Maximale Anzahl von Wiederholungsversuchen
$logFilePath = "c:\tools\upload_log.txt" # Pfad zur Log-Datei
$timeoutInMilliSeconds = 43200000 # 12 Stunden in Millisekunden

# Module prüfen und ggf. aktualisieren
$moduleNames = @("Microsoft.Online.SharePoint.PowerShell", "SharePointPnPPowerShellOnline") # Namen der Module 

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

# Benutzeranmeldeinformationen konvertieren
$Password = ConvertTo-SecureString $PasswordPlainText -AsPlainText -Force
$Creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $Password

# Verbindungsaufbau zu SharePoint
Connect-PnPOnline -Url $siteUrl -Credentials $Creds -RequestTimeout $timeoutInMilliSeconds

# Log-Funktion
function Write-Log {
    param (
        [string]$Message
    )
    Add-Content -Path $logFilePath -Value "$(Get-Date) - $Message"
}

# Datei-Upload-Funktion mit Wiederholungslogik
function Upload-File {
    param (
        [string]$filePath,
        [string]$sharePointPath,
        [int]$retryCount = 0
    )

    try {
        Add-PnPFile -Path $filePath -Folder $sharePointPath
        Write-Host "Datei hochgeladen: $filePath"
    } catch {
        Write-Log "Fehler beim Hochladen der Datei: $filePath - $_"
        if ($retryCount -lt $maxRetryCount) {
            Start-Sleep -Seconds 5 # Kurze Pause vor dem Wiederholungsversuch
            Upload-File -filePath $filePath -sharePointPath $sharePointPath -retryCount ($retryCount + 1)
        } else {
            Write-Log "Maximale Wiederholungsversuche erreicht für: $filePath"
        }
    }
}

# Funktion zum Hochladen eines Ordners
function Upload-Folder {
    param (
        [string]$localPath,
        [string]$sharePointPath
    )

    # Durchsuchen des lokalen Ordners
    Get-ChildItem -Path $localPath -Recurse | ForEach-Object {
        if (!$_.PSIsContainer) {
            $relativeFilePath = $_.FullName.Substring($localFolderPath.Length + 1)
            $sharePointFilePath = "$sharePointPath/$relativeFilePath"
            Upload-File -filePath $_.FullName -sharePointPath $sharePointFilePath
        }
    }
}

# Ordnerstruktur hochladen
Upload-Folder -localPath $localFolderPath -sharePointPath $relativeUrl
