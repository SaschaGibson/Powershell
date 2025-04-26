if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
  Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Force
}
Import-Module Microsoft.Graph.Authentication

Connect-MgGraph -AccessToken $azToken.Token
