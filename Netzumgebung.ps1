# Definieren Sie den IP-Bereich
$ipRange = 1..254 | ForEach-Object { $secondOctet = $_; 1..254 | ForEach-Object { "172.27.$secondOctet.$_" } }

# Gehen Sie durch den IP-Bereich und versuchen Sie, eine Verbindung herzustellen
$ipRange | ForEach-Object { Test-Connection -ComputerName $_ -Count 1 -ErrorAction SilentlyContinue | Out-Null }

# Verwenden Sie nun Get-NetNeighbor, um Informationen zu sammeln
$ipRange | ForEach-Object { Get-NetNeighbor -IPAddress $_ -ErrorAction SilentlyContinue }
