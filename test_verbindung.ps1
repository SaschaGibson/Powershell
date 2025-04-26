# Verbindungsherstellung
Install-Module -Name Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser
update-Module -Name Microsoft.Online.SharePoint.PowerShell
Install-Module -Name SharePointPnPPowerShellOnline -Scope CurrentUser
update-Module -Name SharePointPnPPowerShellOnline


$User = "sascha.gibson@beta-hilfen.de"
$Password = ConvertTo-SecureString "BHE2020sg" -AsPlainText -Force
$Creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $Password
$timeoutInMilliSeconds = 43200000 # 12 Stunden in Millisekunden
$siteUrl = "https://IhrUnternehmen.sharepoint.com"
Connect-PnPOnline -Url https://betahilfen.sharepoint.com -Credential $Creds -RequestTimeout $timeoutInMilliSeconds

# Intervall für den Test in Sekunden
$interval = 10

while ($true) {
    try {
        # Versucht, eine kleine Anfrage zu senden
        $site = Get-PnPSite
        Write-Host "Verbindung aktiv - $(Get-Date)"
    } catch {
        Write-Host "Verbindung verloren oder Fehler - $(Get-Date)"
        # Versuchen Sie erneut, die Verbindung herzustellen
        Connect-PnPOnline -Url $siteUrl -Credentials (Get-Credential)
    }
    # Warten für das nächste Intervall
    Start-Sleep -Seconds $interval
}
