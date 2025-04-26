# Definiert das Ausgangsverzeichnis und die finale requirements.txt Datei
$OutputDir = Get-Location
$FinalReqFile = Join-Path -Path $OutputDir -ChildPath "requirements.txt"

# Falls die finale requirements.txt Datei existiert, wird sie gelöscht
if (Test-Path $FinalReqFile) {
    Remove-Item $FinalReqFile
}

# Durchsucht das Ausgangsverzeichnis und alle Unterverzeichnisse
Get-ChildItem -Path $OutputDir -Recurse -Directory | ForEach-Object {
    # Führt pipreqs für jedes Verzeichnis aus
    pipreqs $_.FullName --force

    # Fügt die Inhalte der erzeugten requirements.txt Dateien zur finalen requirements.txt Datei hinzu
    $ReqFile = Join-Path -Path $_.FullName -ChildPath "requirements.txt"
    if (Test-Path $ReqFile) {
        Get-Content $ReqFile | Out-File -Append -FilePath $FinalReqFile

        # Löscht die erzeugte requirements.txt Datei im Unterverzeichnis
        Remove-Item $ReqFile
    }
}
