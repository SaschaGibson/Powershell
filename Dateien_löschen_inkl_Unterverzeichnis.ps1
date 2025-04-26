# Suche nach Dateien mit einer bestimmten Dateimaske und lösche sie

# Aktuelles Verzeichnis
$rootPath = Get-Location

# Dateimaske
$fileMask = "*.*proj"

# Suche nach Dateien mit der angegebenen Dateimaske im aktuellen Verzeichnis und allen Unterverzeichnissen
$files = Get-ChildItem -Path $rootPath -Filter $fileMask -File -Recurse

# Schleife über alle gefundenen Dateien und lösche sie
foreach ($file in $files) {
    Remove-Item -Path $file.FullName -Force
}
