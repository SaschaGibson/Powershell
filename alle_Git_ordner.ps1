Get-ChildItem -Path "C:\" -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { ($_.PSIsContainer) -and (Test-Path "$($_.FullName)\.git") } | Select-Object FullName
