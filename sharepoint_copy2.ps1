Install-Module -Name Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser
update-Module -Name Microsoft.Online.SharePoint.PowerShell
Install-Module -Name SharePointPnPPowerShellOnline -Scope CurrentUser
update-Module -Name SharePointPnPPowerShellOnline


$User = "sascha.gibson@beta-hilfen.de"
$Password = ConvertTo-SecureString "BHE2020sg" -AsPlainText -Force
$Creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $Password
$timeoutInMilliSeconds = 43200000 # 12 Stunden in Millisekunden

Connect-PnPOnline -Url https://betahilfen.sharepoint.com -Credential $Creds -RequestTimeout $timeoutInMilliSeconds

try {

    Add-PnPFile -Path "C:\Tools\test.pdf" -Folder "/Apps"
} catch {
    Write-Host "Fehler: $_"
}
