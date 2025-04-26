$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object System.Security.Principal.WindowsPrincipal($identity)

if ($principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Output "✅ Du bist Administrator (erhöhte Sitzung)."
} else {
    Write-Output "❌ Du bist KEIN Administrator."
}
