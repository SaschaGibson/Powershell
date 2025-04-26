# Funktion um Administratorrechte zu prüfen
function IsAdmin() {
    # Erstellt ein neues Objekt, das den aktuellen Benutzer repräsentiert
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    # Überprüft, ob der aktuelle Benutzer in der Gruppe der Administratoren ist
    $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

# Funktion um Fehler abzufangen
function ExecuteWithTryCatch($command) {
    try {
        # Führt den Befehl aus und überwacht auf Fehler
        iex $command
    }
    catch {
        # Bei Auftreten eines Fehlers, gibt den Fehler und den betroffenen Befehl aus
        Write-Output "Ein Fehler ist aufgetreten während der Ausführung des folgenden Befehls: $command. Fehlerdetails: $_"
    }
}

# Prüft ob das Skript mit Administratorrechten ausgeführt wird
if ((IsAdmin) -eq $false) {
    # Wenn das Skript ohne Administratorrechte ausgeführt wird, wird eine Aufforderung zur Erhöhung der Berechtigungen ausgegeben und das Skript beendet
    Write-Output "Bitte starten Sie das Skript mit Administratorrechten"
    return
}

# Setzt das Konsolen-Encoding auf CodePage 1252, um spezielle Zeichen korrekt darzustellen
[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding(1252)


# Hauptmenü in einer Schleife, die auf Benutzereingaben wartet und entsprechende Befehle ausführt
do {
    # Löscht den Konsolentext vor jedem Durchlauf
    Clear-Host
    # Zeigt dem Benutzer die verfügbaren Aktionen
    Write-Output "Bitte wählen Sie eine Aktion:"
    Write-Output "1. Chkdsk auf Systemlaufwerk ausführen"
    Write-Output "2. Chkdsk auf Nicht-Systemlaufwerken ausführen"
    Write-Output "3. Systemdateien überprüfen und reparieren"
    Write-Output "4. Systemabbild bereinigen und reparieren"
    Write-Output "5. Disk Cleanup ausführen"
    Write-Output "6. Windows Update prüfen"
    Write-Output "7. Festplatte defragmentieren"
    Write-Output "8. Windows-Speicherdiagnosetool ausführen"
    Write-Output "9. Windows Defender Scan ausführen"
    Write-Output "10. Performance Monitor Bericht erstellen"
    Write-Output "11. Laufende Prozesse anzeigen"
    Write-Output "12. Beenden"

    # Fordert den Benutzer zur Eingabe einer Aktion auf
    $input = Read-Host "Bitte geben Sie die Nummer der gewünschten Aktion ein"

    # Abhängig von der Benutzereingabe wird der entsprechende Befehl ausgeführt
    switch ($input) {
        '1' {
            # Führt eine chkdsk-Prüfung auf dem Systemlaufwerk aus
            ExecuteWithTryCatch "chkdsk ${env:\SYSTEMDRIVE}"
            break
        }
        '2' {
            # Führt eine chkdsk-Prüfung auf allen Nicht-Systemlaufwerken aus
            foreach ($lw in (Get-Volume | Where-Object { $_.OperationalStatus -eq 'OK' -and $_.DriveType -ne 'CD-ROM' -and $_.DriveLetter -and $_.DriveLetter -ne $env:SYSTEMDRIVE[0] })) {
                $lwb = $lw.DriveLetter + ":"
                ExecuteWithTryCatch "chkdsk $lwb /f /x"
            }
            break
        }
        '3' {
            # Führt den Befehl 'sfc /scannow' aus, um Systemdateien zu überprüfen und zu reparieren
            ExecuteWithTryCatch "sfc /scannow"
            break
        }
        '4' {
            # Führt DISM-Befehle aus, um das Systemabbild zu bereinigen und zu reparieren
            ExecuteWithTryCatch "dism /online /cleanup-image /restorehealth"
            ExecuteWithTryCatch "dism /online /cleanup-image /startcomponentcleanup"
            break
        }
        '5' {
            # Führt Disk Cleanup mit der Set 50 aus
            ExecuteWithTryCatch "cleanmgr /sageset:50"
            ExecuteWithTryCatch "cleanmgr /sagerun:50"
            break
        }
        '6' {
            # Überprüft auf Windows-Updates und installiert das PSWindowsUpdate-Modul, wenn es nicht vorhanden ist
            if (-not (Get-InstalledModule -Name "PSWindowsUpdate")) {
                Write-Output "Das PSWindowsUpdate-Modul wird installiert..."
                Install-Module -Name "PSWindowsUpdate" -Force -Confirm:$false
            }
            ExecuteWithTryCatch "Get-WindowsUpdate"
            break
        }
        '7' {
            # Führt die Defragmentierung auf dem Systemlaufwerk aus
            ExecuteWithTryCatch "defrag ${env:\SYSTEMDRIVE} /U /V"
            break
        }
        '8' {
            # Führt das Windows-Speicherdiagnosetool aus
            ExecuteWithTryCatch "msched"
            break
        }
        '9' {
            # Führt einen Windows Defender Scan aus und installiert das Defender-Modul, wenn es nicht vorhanden ist
            if (-not (Get-InstalledModule -Name "Defender")) {
                Write-Output "Das Defender-Modul wird installiert..."
                Install-Module -Name "Defender" -Force -Confirm:$false
            }
            ExecuteWithTryCatch "Start-MpScan -ScanType QuickScan"
            break
        }
        '10' {
            # Erstellt einen Performance Monitor Bericht
            ExecuteWithTryCatch "perfmon /report"
            break
        }
        '11' {
            # Zeigt alle laufenden Prozesse an
            ExecuteWithTryCatch "tasklist"
            break
        }
        '12' {
            # Beendet das Skript
            return
        }
    }

    # Fordert den Benutzer auf, eine Taste zu drücken, um fortzufahren
    Write-Output "Drücken Sie eine beliebige Taste, um fortzufahren"
    $host.UI.RawUI.ReadKey('NoEcho, IncludeKeyDown') | Out-Null

} while ($true)

