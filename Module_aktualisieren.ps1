$updatedModules = 0
pip list --outdated --format=columns | Select-String -Pattern '\S+' | ForEach-Object {
    $moduleName = $_.Matches.Value
    pip install -U --force-reinstall $moduleName -q --no-cache-dir
    if ($LASTEXITCODE -eq 0) {
        $updatedModules++
    }
}
Write-Output "Anzahl der aktualisierten Module: $updatedModules"
