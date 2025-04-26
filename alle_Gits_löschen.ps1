Get-ChildItem -Path "C:\" -Recurse -Force -ErrorAction SilentlyContinue | 
Where-Object { ($_.PSIsContainer) -and (Test-Path "$($_.FullName)\.git") } | 
ForEach-Object {
    $confirmation = Read-Host "Sind Sie sicher, dass Sie das .git Verzeichnis in $($_.FullName) löschen möchten? (y/n)"
    if ($confirmation -eq 'y') {
        Remove-Item "$($_.FullName)\.git" -Force -Recurse
        Write-Host "Das .git Verzeichnis in $($_.FullName) wurde gelöscht."
    }
}
