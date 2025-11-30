# ConnectionManager V6  
Portabler RDP- und SSH-Manager für Windows.  
Keine Installation, keine Registry, keine externen Tools.  
Eine einzelne PowerShell-Datei und eine CSV als "Mini-Datenbank".

---

## 1. Zweck des Tools

Der ConnectionManager dient als schneller, portabler Verbindungsmanager für:

- Homelab
- IT-Ausbildung
- Notebook-Wechselnetze
- Proxmox- oder VMware-Lab
- Unterwegs (USB-Stick)
- Kleine Firmen-Supportumgebungen

Alles läuft lokal ohne Fremdsoftware.

---

## 2. Aufbau

Ordnerstruktur:

ConnectionManager/
ConnectionManagerV6.ps1
connections.csv (automatisch erzeugt)

Das Script und die CSV müssen im selben Ordner liegen.  
Es gibt keine weiteren Abhängigkeiten.

---

## 3. Erste Schritte

### Script starten

powershell.exe -ExecutionPolicy Bypass -File .\ConnectionManagerV6.ps1


Beim ersten Start wird automatisch eine neue CSV erzeugt.

---

## 4. CSV-Datei (Datenbank)

Die CSV enthält alle Verbindungsdaten.

**Spaltenaufbau:**

id;Name;OS;IP;Protocol;Username;Password;Kommentar


Beispiel:
3;Uranus;Windows;192.168.100.5;rdp;Administrator;Passwort123;Proxmox Test


Die CSV ist bewusst einfach gehalten, damit:

- portable
- editierbar
- versionierbar
- cloud-sync-fähig

---

## 5. Funktionen im Script

### 5.1 Einträge anzeigen
Listet alle gespeicherten Systeme.

### 5.2 Eintrag hinzufügen
Fragt alle Werte ab, erstellt neue ID, speichert direkt.

### 5.3 Eintrag bearbeiten
Ändert Werte eines bestehenden Systems.

### 5.4 Eintrag löschen
Löscht ausgewählten Eintrag nach Bestätigung.

### 5.5 Backup erstellen
Legt eine Kopie der CSV an mit Datum/Zeit.

### 5.6 Dynamic Subnet Matching
Das Script erkennt lokale IPs und sortiert Systeme nach Netz-Nähe:

- gleiches /24 Netzwerk (höchste Priorität)
- gleiches /16
- gleicher erster Block
- Rest untergeordnet

So stehen relevante Ziele automatisch oben.

### 5.7 Session-Status (RDP)
Über WinRM und "quser" erkennt das Script:

- eigener Nutzer aktiv
- eigener Nutzer getrennt
- anderer Nutzer aktiv
- keine Session
- unbekannt

### 5.8 Verbindung herstellen

**RDP:**
- Credentials werden temporär via cmdkey gesetzt
- eine temporäre .rdp Datei wird erzeugt
- mstsc startet direkt

**SSH:**
- Powershell-Fenster öffnet sich mit SSH-Kommando

---

## 6. Nutzung über Cloud (Empfehlung)

Da die CSV Zugangsdaten enthält, ist es sinnvoll, den Ordner in einer sicheren Cloud zu speichern:

- OneDrive
- Dropbox
- Google Drive
- Synology Drive
- Nextcloud

Vorteile:

- die CSV bleibt privat
- kann von mehreren Geräten genutzt werden
- automatische Backups
- Script bleibt portable

### Beispiel-Setup
C:\Users\NAME\OneDrive\ConnectionManager\


Dann eine Verknüpfung auf den Desktop legen:

powershell.exe -ExecutionPolicy Bypass -File "C:\Users\NAME\OneDrive\ConnectionManager\ConnectionManagerV6.ps1"


---

## 7. Sicherheitshinweise

- Die CSV speichert Passwörter im Klartext (für Portabilität).
- Kein Logging, keine Telemetrie, kein externes Tracking.
- Für produktive Umgebungen sollte Passwortverschlüsselung ergänzt werden.
- WinRM muss für RDP-Status aktiv sein.

---

## 8. Typische Anwendungsfälle

- Homelab-Server verwalten
- Proxmox-Node RDP/SSH
- Windows-Testnetzwerke
- Ausbildung (FISI/IT)
- Lab auf USB-Stick
- Temporäre Kundennetze
- Notebook im wechselnden Firmennetz

---

## 9. Erweiterungsmöglichkeiten

Das Script ist modular und kann leicht erweitert werden:

- DPAPI- oder AES-Verschlüsselung für Passwörter
- GUI (WPF / WinForms)
- SQLite statt CSV
- Import/Export
- Auto-Connect-Profile
- Multi-CSV Support
- Gruppenverwaltung

Je nach Bedarf, kann jede dieser Funktionen integriert werden.

---

## 10. Mitwirkung

Dieses Projekt ist offen zur Erweiterung.  
Pull Requests oder eigene Forks sind erwünscht.








