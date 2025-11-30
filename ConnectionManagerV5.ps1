<#
RDP/SSH Manager (Offline-Lab, portable Version)
Autor: Logi

Version 6 – Vollversion
Features:
- CSV-Verwaltung (Add/Edit/Delete/Backup)
- Sortierung nach aktivem Subnetz
- Extra-Spalte „Verfügbar“ im Connect-Menü (Ping)
- RDP-Statusprüfung via WinRM + quser
- Admin-Autostart, bleibt offen beim Doppelklick
#>

# --- Automatische Admin-Ausführung ---
$flagFile = "$env:TEMP\logi_admin_elevated.flag"

if (-not (Test-Path $flagFile)) {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltinRole] "Administrator")
    if (-not $isAdmin) {
        Write-Host "⚙️  Starte neu mit Administratorrechten..."
        Start-Sleep -Milliseconds 300
        Set-Content -Path $flagFile -Value "1" -Encoding ASCII -Force
        $currExe = (Get-Process -Id $PID -ErrorAction SilentlyContinue).Path
        if (-not $currExe) { $currExe = "powershell.exe" }
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $currExe
        $scriptPath = $MyInvocation.MyCommand.Definition
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
        $psi.Verb = "runas"
        [System.Diagnostics.Process]::Start($psi) | Out-Null
        exit
    }
} else {
    Remove-Item -Path $flagFile -ErrorAction SilentlyContinue
}

# --- Grundkonfiguration ---
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$DataFile  = Join-Path $ScriptDir "connections.csv"
$Delimiter = ';'

function Ensure-DataPath {
    if (-not (Test-Path $DataFile)) {
        "id${Delimiter}Name${Delimiter}OS${Delimiter}IP${Delimiter}Protocol${Delimiter}Username${Delimiter}Password${Delimiter}Kommentar" |
            Out-File -FilePath $DataFile -Encoding UTF8 -Force
        Write-Host "📁 Neue CSV angelegt: $DataFile"
    }
}

function Load-Connections {
    Ensure-DataPath
    try {
        Import-Csv -Path $DataFile -Delimiter $Delimiter -ErrorAction Stop
    } catch {
        Write-Warning "⚠️ Fehler beim Laden der CSV-Datei: $_"
        @()
    }
}

function Save-Connections($list) {
    Ensure-DataPath
    if ($null -eq $list) { $list = @() }
    elseif ($list -isnot [System.Collections.IEnumerable] -or $list -is [string]) { $list = @($list) }

    try {
        $list | Export-Csv -Path $DataFile -Delimiter $Delimiter -NoTypeInformation -Encoding UTF8 -Force
        Write-Host "💾 Daten gespeichert unter $DataFile"
    } catch {
        Write-Warning "❌ Fehler beim Speichern: $_"
    }
}

function Show-List {
    $list = Load-Connections
    if (-not $list -or $list.Count -eq 0) {
        Write-Host "Keine Einträge vorhanden." -ForegroundColor DarkGray
        return
    }
    "{0,-4} {1,-25} {2,-10} {3,-15} {4,-6} {5,-15}" -f "ID","Name","OS","IP","Proto","User"
    foreach ($e in $list) {
        "{0,-4} {1,-25} {2,-10} {3,-15} {4,-6} {5,-15}" -f $e.id, $e.Name, $e.OS, $e.IP, $e.Protocol, $e.Username
    }
}

function Get-NextId($list) {
    if (-not $list -or $list.Count -eq 0) { return 1 }
    $max = ($list | ForEach-Object { [int]$_.id } | Measure-Object -Maximum).Maximum
    return ($max + 1)
}

function Add-Connection {
    $list = Load-Connections
    $id = Get-NextId $list
    $Name = Read-Host "Name"
    $OS   = Read-Host "OS (z.B. Windows/Linux)"
    $IP   = Read-Host "IP-Adresse"
    do {
        $Proto = Read-Host "Protocol (rdp/ssh)"
        $Proto = $Proto.ToLower()
    } until ($Proto -in @('rdp','ssh'))
    $User = Read-Host "Benutzername"
    $Pass = Read-Host "Passwort (Klartext)"
    $Comment = Read-Host "Kommentar (optional)"

    $entry = [PSCustomObject]@{
        id       = $id
        Name     = $Name
        OS       = $OS
        IP       = $IP
        Protocol = $Proto
        Username = $User
        Password = $Pass
        Kommentar= $Comment
    }

    $list += $entry
    Save-Connections $list
    Write-Host "✅ Eintrag hinzugefügt (ID $id)."
}

function Edit-Connection {
    $list = Load-Connections
    if (-not $list -or $list.Count -eq 0) { Write-Host "Keine Einträge."; return }
    Show-List
    $id = Read-Host "ID zum Bearbeiten"
    $entry = $list | Where-Object { $_.id -eq $id }
    if (-not $entry) { Write-Host "ID nicht gefunden."; return }

    $entry.Name      = Read-Host "Name [$($entry.Name)]" -Default $entry.Name
    $entry.OS        = Read-Host "OS [$($entry.OS)]" -Default $entry.OS
    $entry.IP        = Read-Host "IP [$($entry.IP)]" -Default $entry.IP
    do {
        $p = Read-Host "Protocol (rdp/ssh) [$($entry.Protocol)]" -Default $entry.Protocol
        $p = $p.ToLower()
    } until ($p -in @('rdp','ssh'))
    $entry.Protocol  = $p
    $entry.Username  = Read-Host "Benutzername [$($entry.Username)]" -Default $entry.Username
    $entry.Password  = Read-Host "Passwort [$($entry.Password)]" -Default $entry.Password
    $entry.Kommentar = Read-Host "Kommentar [$($entry.Kommentar)]" -Default $entry.Kommentar

    $list = ($list | Where-Object { $_.id -ne $id }) + $entry | Sort-Object {[int]$_.id}
    Save-Connections $list
    Write-Host "✅ Eintrag $id aktualisiert."
}

function Remove-Connection {
    $list = Load-Connections
    if (-not $list -or $list.Count -eq 0) { Write-Host "Keine Einträge."; return }
    Show-List
    $id = Read-Host "Gib die ID zum Löschen ein"
    $entry = $list | Where-Object { $_.id -eq $id }
    if (-not $entry) { Write-Host "ID nicht gefunden."; return }
    $confirm = Read-Host "Sicher löschen? (J/N)"
    if ($confirm -notin @('J','j','Y','y')) { Write-Host "Abgebrochen."; return }
    $list = $list | Where-Object { $_.id -ne $id }
    Save-Connections $list
    Write-Host "🗑️  Eintrag $id gelöscht."
}

function Backup-File {
    Ensure-DataPath
    $bak = Join-Path (Split-Path $DataFile -Parent) ("connections_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".bak.csv")
    Copy-Item -Path $DataFile -Destination $bak -Force
    Write-Host "💾 Backup erstellt: $bak"
}

# --- RDP Status via WinRM + quser ---
function Get-RdpSessionState {
    param([string]$ip,[string]$user,[string]$pass)

    function Parse-RemoteQuserOutput {
        param([string[]]$lines,[string]$targetUser)
        foreach ($line in $lines) {
            if ($line -match '^\s*(?<usr>\S+)\s+(?<sess>[\w#\-]+)\s+(?<id>\d+)\s+(?<state>\S+)') {
                $usr = $matches['usr']; $state = $matches['state']
                if ($usr -ieq $targetUser) {
                    if ($state -match 'Active|Aktiv') { return "ActiveUser" }
                    elseif ($state -match 'Disc|Getrennt') { return "DiscUser" }
                } elseif ($state -match 'Active|Aktiv') { return "ActiveOther" }
            }
        }
        return "None"
    }

    try {
        $secure = ConvertTo-SecureString $pass -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential ($user,$secure)
        $result = Invoke-Command -ComputerName $ip -Credential $cred -Authentication Basic -UseSSL:$false -ErrorAction Stop -ScriptBlock { quser /server:localhost 2>&1 }
        if ($result) { return (Parse-RemoteQuserOutput -lines $result -targetUser $user) }
        else { return "Unknown" }
    } catch { return "Unknown" }
}

# --- Dynamische Netzwerkerkennung & Sortierung (ohne Ping, rein logische Nähe) ---
function Sort-Connections-ByActiveSubnet {
    param([array]$Connections)
    try {
        # Lokale IPv4-Adressen holen (ohne APIPA/Loopback)
        $localIPs = Get-NetIPAddress -AddressFamily IPv4 |
            Where-Object {
                $_.IPAddress -match '^\d+\.\d+\.\d+\.\d+$' -and
                $_.IPAddress -notmatch '^169\.254' -and
                $_.IPAddress -ne '127.0.0.1'
            } |
            Select-Object InterfaceAlias, IPAddress

        if (-not $localIPs -or $localIPs.Count -eq 0) {
            Write-Host "⚠️  Keine lokalen IPv4-Adressen erkannt." -ForegroundColor Yellow
            return $Connections
        }

        Write-Host ""
        Write-Host "🌐 Aktive lokale Netze erkannt:" -ForegroundColor Cyan
        foreach ($ip in $localIPs) {
            Write-Host ("  {0,-20} {1,-15}" -f $ip.InterfaceAlias, $ip.IPAddress) -ForegroundColor DarkGray
        }

        foreach ($conn in $Connections) {
            $conn | Add-Member -NotePropertyName "MatchScore" -NotePropertyValue 0 -Force
            $conn | Add-Member -NotePropertyName "Verfügbar" -NotePropertyValue "❌" -Force

            foreach ($ip in $localIPs) {
                $connNet3 = ($conn.IP -split '\.')[0..2] -join '.'
                $localNet3 = ($ip.IPAddress -split '\.')[0..2] -join '.'
                $connNet2 = ($conn.IP -split '\.')[0..1] -join '.'
                $localNet2 = ($ip.IPAddress -split '\.')[0..1] -join '.'
                $connNet1 = ($conn.IP -split '\.')[0]
                $localNet1 = ($ip.IPAddress -split '\.')[0]

                if ($connNet3 -eq $localNet3) {
                    $conn.MatchScore = 5
                    $conn.Verfügbar = "✅"
                    break
                }
                elseif ($connNet2 -eq $localNet2) {
                    $conn.MatchScore = [Math]::Max($conn.MatchScore, 3)
                    $conn.Verfügbar = "🟨"
                }
                elseif ($connNet1 -eq $localNet1) {
                    $conn.MatchScore = [Math]::Max($conn.MatchScore, 1)
                    $conn.Verfügbar = "⚪"
                }
            }
        }

        Write-Host ""
        Write-Host "📋 Sortierung nach Subnetz-Übereinstimmung abgeschlossen." -ForegroundColor Cyan
        return ($Connections | Sort-Object -Property MatchScore -Descending)
    }
    catch {
        Write-Host "⚠️ Fehler bei Netzwerkerkennung: $_" -ForegroundColor Yellow
        return $Connections
    }
}


# --- Status + Connect ---
function Show-Status-Then-Prompt {
    param([string]$ip,[string]$proto,[string]$username,[string]$password)
    $state = "Unknown"
    if ($proto -eq 'rdp') {
        $state = Get-RdpSessionState -ip $ip -user $username -pass $password
    } elseif ($proto -eq 'ssh') {
        if (Test-Connection -Count 1 -Quiet -ComputerName $ip) { $state="None" } else { $state="Unavailable" }
    }

    switch ($state) {
        "ActiveUser" { Write-Host "🟥 Du bist aktiv eingeloggt ($username)" -ForegroundColor Red }
        "DiscUser" { Write-Host "🟨 Deine Sitzung ist getrennt" -ForegroundColor Yellow }
        "ActiveOther" { Write-Host "🟧 Anderer Benutzer aktiv" -ForegroundColor DarkYellow }
        "None" { Write-Host "🟩 Keine aktive Sitzung" -ForegroundColor Green }
        default { Write-Host "🟡 Status unbekannt" -ForegroundColor Yellow }
    }

    $proceed = Read-Host "Weiter mit Verbindung? (J/N)"
    return ($proceed -in @('J','j','Y','y'))
}

function Connect-Entry {
    $list = Sort-Connections-ByActiveSubnet -Connections (Load-Connections)
    if (-not $list -or $list.Count -eq 0) { Write-Host "Keine gespeicherten Einträge."; return }

    "{0,-4} {1,-25} {2,-10} {3,-15} {4,-6} {5,-15} {6,-10}" -f "ID","Name","OS","IP","Proto","User","Verfügbar"
    foreach ($e in $list) {
        "{0,-4} {1,-25} {2,-10} {3,-15} {4,-6} {5,-15} {6,-10}" -f $e.id,$e.Name,$e.OS,$e.IP,$e.Protocol,$e.Username,$e.Verfügbar
    }

    $id = Read-Host "Gib die ID für die Verbindung ein"
    $entry = $list | Where-Object { $_.id -eq $id }
    if (-not $entry) { Write-Host "ID nicht gefunden."; return }

    Write-Host "`n🔍 Prüfe Verbindung zu $($entry.IP) ..."
    $ok = Show-Status-Then-Prompt -ip $entry.IP -proto $entry.Protocol -username $entry.Username -password $entry.Password
    if (-not $ok) { Write-Host "Abgebrochen."; return }

    switch ($entry.Protocol) {
        'rdp' {
            cmd.exe /c "cmdkey /generic:TERMSRV/$($entry.IP) /user:`"$($entry.Username)`" /pass:`"$($entry.Password)`"" | Out-Null
            $rdpFile = Join-Path $env:TEMP ("logi_rdp_$($entry.IP).rdp")
            @"
full address:s:$($entry.IP)
prompt for credentials:i:0
username:s:$($entry.Username)
"@ | Set-Content -Path $rdpFile -Encoding ASCII
            Start-Process "mstsc.exe" -ArgumentList $rdpFile
        }
        'ssh' { Start-Process "powershell.exe" "-NoExit -Command `"ssh $($entry.Username)@$($entry.IP)`"" }
    }
}

# --- Hauptmenü ---
function Main-Menu {
    while ($true) {
        Write-Host ""
        Write-Host "==== Connections Manager ===="
        Write-Host "[L] Liste anzeigen"
        Write-Host "[A] Hinzufügen"
        Write-Host "[E] Editieren"
        Write-Host "[D] Löschen"
        Write-Host "[B] Backup"
        Write-Host "[C] Connect"
        Write-Host "[Q] Beenden"
        $c = Read-Host "Auswahl"

        switch ($c.ToUpper()) {
            'L' { Show-List }
            'A' { Add-Connection }
            'E' { Edit-Connection }
            'D' { Remove-Connection }
            'B' { Backup-File }
            'C' { Connect-Entry }
            'Q' { break }
            default { Write-Host "Ungültige Auswahl." }
        }
    }
    Write-Host "`nProgramm beendet. Drücke eine Taste zum Schließen..."
    Pause
}

# === Startpunkt ===
Ensure-DataPath
Main-Menu
