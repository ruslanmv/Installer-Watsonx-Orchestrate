# ===============================
# watsonx ADK Installer (Windows)
# ===============================

# --- Config (paths resolved safely) ---
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$envFile  = Join-Path $RepoRoot '.env'
$venvDir  = Join-Path $RepoRoot 'venv'
$adkVersions = @('1.5.0','1.5.1','1.6.0','1.6.1','1.6.2','1.7.0')
$pythonCmd = 'python'  # fallback if venv Python not found

# --- Helpers ---
function CommandExists {
    param([Parameter(Mandatory)][string]$cmd)
    try { Get-Command $cmd -ErrorAction Stop | Out-Null; return $true } catch { return $false }
}

function Pause-ForUser {
    param([string]$Message = "Premi INVIO per continuare...")
    [void](Read-Host $Message)
}

# Load .env into current session (process scope)
function Load-DotEnv {
    param([Parameter(Mandatory)][string]$envFile)

    if (-not (Test-Path -LiteralPath $envFile)) {
        Write-Host "File .env non trovato: $envFile" -ForegroundColor Red
        exit 1
    }

    Write-Host "Caricamento .env da: $envFile`n"
    Get-Content -LiteralPath $envFile | ForEach-Object {
        $line = $_.Trim()
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) { return }

        if ($line -notmatch '=') {
            Write-Host "Riga ignorata (nessun '=' valido): $line" -ForegroundColor Yellow
            return
        }

        $parts = $line -split '=', 2
        if ($parts.Count -ne 2) {
            Write-Host "Riga malformata: $line" -ForegroundColor Yellow
            return
        }

        $name  = $parts[0].Trim()
        $value = $parts[1].Trim()

        # Rimuovi virgolette esterne se presenti
        if ($value.Length -ge 2 -and (
            ($value.StartsWith('"') -and $value.EndsWith('"')) -or
            ($value.StartsWith("'") -and $value.EndsWith("'"))
        )) {
            $value = $value.Substring(1, $value.Length - 2)
        }

        if (-not [string]::IsNullOrWhiteSpace($name)) {
            ${env:$name} = $value
            Write-Host "ENV set: $name"
        }
    }
}

# Crea venv (con scelta se esiste già)
function Create-Venv {
    if (Test-Path -LiteralPath $venvDir) {
        Write-Host "Virtualenv già presente: $venvDir"
        do {
            $choice = Read-Host "Vuoi riutilizzarlo (1), ricrearlo (2) o uscire (3)?"
        } until ($choice -in @('1','2','3'))

        switch ($choice) {
            '1' { return }
            '2' {
                try {
                    Remove-Item -Recurse -Force -LiteralPath $venvDir
                } catch {
                    Write-Host "Errore durante la rimozione del venv: $($_.Exception.Message)" -ForegroundColor Red
                    exit 1
                }
            }
            '3' { exit 0 }
        }
    }

    Write-Host "Creo ambiente virtuale in '$venvDir'..."
    # usa 'python' globale; se vuoi forzare 3.11 usa 'py -3.11 -m venv ...'
    & $pythonCmd -m venv $venvDir
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Creazione del venv fallita. Verifica l'installazione di Python." -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

# Restituisce l'eseguibile Python da usare (preferisci quello del venv)
function Get-VenvPython {
    $vp = Join-Path $venvDir 'Scripts\python.exe'
    if (Test-Path -LiteralPath $vp) { return $vp }
    return $pythonCmd
}

# "Attiva" venv (nota: non puoi cambiare l'ambiente della sessione chiamante da uno script)
function Activate-Venv {
    $activateScript = Join-Path $venvDir 'Scripts\Activate.ps1'
    if (!(Test-Path -LiteralPath $activateScript)) {
        Write-Host "Impossibile attivare il venv: $activateScript" -ForegroundColor Red
        exit 1
    }
    Write-Host "Per attivare il venv nella tua shell:"
    Write-Host "  `"$activateScript`""
    Write-Host "(Lo script prosegue comunque usando direttamente l'eseguibile Python del venv.)"
}

# Installa ADK usando il Python selezionato
function Install-ADK {
    param([string]$Version = 'latest')

    $py = Get-VenvPython
    Write-Host "Uso Python: $py"

    # Assicurati che pip ci sia/aggiornato
    & $py -m pip install --upgrade pip
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Aggiornamento pip fallito." -ForegroundColor Red
        exit $LASTEXITCODE
    }

    Write-Host "Installo watsonx Orchestrate ADK ($Version)..."
    if ($Version -eq 'latest') {
        & $py -m pip install --upgrade ibm-watsonx-orchestrate
    } else {
        & $py -m pip install "ibm-watsonx-orchestrate==$Version"
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Installazione ADK fallita." -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

# Menu a schermo
function Show-Menu {
    Clear-Host
    Write-Host "`nwatsonx ADK Installer (Windows)" -ForegroundColor Cyan
    Write-Host "1) Full setup (venv + ADK)"
    Write-Host "2) Solo venv"
    Write-Host "3) Installa/aggiorna ADK"
    Write-Host "4) Esci"
}

# =================
#       MAIN
# =================
while ($true) {
    Show-Menu
    $option = Read-Host "`nScegli un'opzione (1-4)"

    switch ($option) {
        '1' {
            # Full setup
            Load-DotEnv -envFile $envFile
            Create-Venv
            Activate-Venv

            $v = Read-Host "Versione ADK (0 = latest) [es: 1.6.2]"
            if ([string]::IsNullOrWhiteSpace($v) -or $v -eq '0') { $v = 'latest' }
            Install-ADK -Version $v

            Write-Host "`nCompletato. Attiva l'ambiente con: .\venv\Scripts\Activate.ps1"
            Pause-ForUser
        }
        '2' {
            # Solo venv
            Create-Venv
            Write-Host "`nAmbiente creato. Attiva con: .\venv\Scripts\Activate.ps1"
            Pause-ForUser
        }
        '3' {
            # Installa/aggiorna ADK dentro venv esistente
            if (!(Test-Path -LiteralPath $venvDir)) {
                Write-Host "Nessun ambiente virtuale trovato. Esegui prima l'opzione 1 o 2." -ForegroundColor Red
                Pause-ForUser
                continue
            }
            Activate-Venv
            $v = Read-Host "Versione ADK (0 = latest) [es: 1.6.2]"
            if ([string]::IsNullOrWhiteSpace($v) -or $v -eq '0') { $v = 'latest' }
            Install-ADK -Version $v
            Pause-ForUser
        }
        '4' {
            Write-Host "Uscita script."
            break
        }
        default {
            Write-Host "Opzione non valida. Inserisci 1, 2, 3 o 4." -ForegroundColor Yellow
            Start-Sleep -Milliseconds 900
        }
    }
}
