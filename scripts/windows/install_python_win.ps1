# install_python_win.ps1 — Installa Python 3.11 su Windows

Write-Host "`n🔧 Controllo presenza di Python 3.11..."

# Controlla se python3.11 è già disponibile
$pythonInstalled = Get-Command python3.11 -ErrorAction SilentlyContinue

if ($pythonInstalled) {
    Write-Host "✅ Python 3.11 è già installato:"
    python3.11 --version
    exit 0
}

Write-Host "🚀 Python 3.11 non trovato. Avvio installazione..."

# Imposta URL e percorso di installazione
$installerUrl = "https://www.python.org/ftp/python/3.11.4/python-3.11.4-amd64.exe"
$installerPath = "$env:TEMP\python311-installer.exe"

# Scarica l’installer
Write-Host "⬇️  Downloading Python 3.11 from python.org..."
Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath

# Installa Python in modo silenzioso, con pip e PATH
Start-Process -FilePath $installerPath -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 Include_pip=1 Include_launcher=1" -Wait

# Elimina installer
Remove-Item $installerPath

# Verifica installazione
$pythonInstalled = Get-Command python3.11 -ErrorAction SilentlyContinue
if (-not $pythonInstalled) {
    Write-Host "❌ Errore: Python 3.11 non si è installato correttamente."
    exit 1
}

# Upgrade pip e pacchetti base
Write-Host "📦 Aggiornamento pip, setuptools e wheel..."
python3.11 -m pip install --upgrade pip setuptools wheel

Write-Host "`n✅ Python 3.11 installato con successo!"
python3.11 --version

Write-Host "`n🔧 Consigli:"
Write-Host "• Per creare un ambiente virtuale:"
Write-Host "    python3.11 -m venv venv"
Write-Host "• Per attivarlo:"
Write-Host "    .\venv\Scripts\Activate.ps1"
Write-Host "• Per installare watsonx Orchestrate ADK:"
Write-Host "    pip install ibm-watsonx-orchestrate"

Write-Host "`n🎉 Python è pronto all’uso!"
