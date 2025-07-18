# Config
$envFile = ".env"
$venvDir = "venv"
$adkVersions = @("1.5.0", "1.5.1", "1.6.0", "1.6.1", "1.6.2", "1.7.0")
$pythonCmd = "python"

# Helper: Check command exists
function CommandExists {
    param ($cmd)
    try {
        Get-Command $cmd -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Helper: Load .env file into current session
function Load-DotEnv {
    param (
        [string]$envFile
    )

    if ([string]::IsNullOrWhiteSpace($envFile) -or !(Test-Path $envFile)) {
        Write-Host "File .env non trovato: $envFile" -ForegroundColor Red
        exit 1
    }

    Write-Host "Caricamento .env da: $envFile`n"

    Get-Content $envFile | ForEach-Object {
        $_ = $_.Trim()
        if ([string]::IsNullOrWhiteSpace($_) -or $_.StartsWith('#')) {
            return
        }

        if ($_ -notmatch '=') {
            Write-Host "Riga ignorata (nessun '=' valido): $_" -ForegroundColor Yellow
            return
        }

        $parts = $_ -split '=', 2

        if ($parts.Count -eq 2) {
            $name = $parts[0].Trim()
            $value = $parts[1].Trim()

            if (![string]::IsNullOrWhiteSpace($name)) {
                Write-Host "ENV set: $name"
                ${env:$name} = $value
            }
        } else {
            Write-Host "Riga malformata: $_" -ForegroundColor Yellow
        }
    }
}

# Create virtual environment
function Create-Venv {
    if (Test-Path $venvDir) {
        Write-Host "Virtualenv già presente: $venvDir"
        $choice = Read-Host "Vuoi riutilizzarlo (1), ricrearlo (2) o uscire (3)?"
        switch ($choice) {
            "1" { return }
            "2" { Remove-Item -Recurse -Force $venvDir }
            "3" { exit 0 }
        }
    }
    Write-Host "Creo ambiente virtuale in '$venvDir'..."
    & $pythonCmd -m venv $venvDir
}

# Attiva ambiente virtuale
function Activate-Venv {
    $activateScript = "$PSScriptRoot\..\..\venv\Scripts\Activate.ps1"

    if (!(Test-Path $activateScript)) {
        Write-Host "Impossibile attivare il venv: $activateScript" -ForegroundColor Red
        exit 1
    }

    Write-Host "Attiva manualmente il venv con: $activateScript"
    Write-Host "Lo script continuerà ma l'ambiente non sarà attivo in questa sessione PowerShell."
}

# Installa ADK
function Install-ADK {
    param (
        [string]$version = "latest"
    )
    Write-Host "Installo watsonx Orchestrate ADK..."
    if ($version -eq "latest") {
        pip install --upgrade ibm-watsonx-orchestrate
    } else {
        pip install "ibm-watsonx-orchestrate==$version"
    }
}

# Menu
function Show-Menu {
    Clear-Host
    Write-Host "`nwatsonx ADK Installer (Windows)" -ForegroundColor Cyan
    Write-Host "1) Full setup (venv + ADK)"
    Write-Host "2) Solo venv"
    Write-Host "3) Installa/aggiorna ADK"
    Write-Host "4) Esci"
}

# MAIN
while ($true) {
    Show-Menu
    $option = Read-Host "`nScegli un'opzione"

    switch ($option) {
        "1" {
            $envFile = "$PSScriptRoot\..\..\scripts\.env"
            Load-DotEnv -envFile $envFile
            Create-Venv
            Activate-Venv

            $v = Read-Host "Versione ADK (0 = latest) [es: 1.6.2]"
            if ([string]::IsNullOrWhiteSpace($v) -or $v -eq "0") {
                $v = "latest"
            }
            Install-ADK -version $v

            Write-Host "`nCompletato. Attiva l'ambiente con: .\venv\Scripts\Activate.ps1"
            pause
        }
        "2" {
            Create-Venv
            Write-Host "`nAmbiente creato. Attiva con: .\venv\Scripts\Activate.ps1"
            pause
        }
        "3" {
            if (!(Test-Path $venvDir)) {
                Write-Host "Nessun ambiente virtuale trovato. Esegui prima l'opzione 1 o 2." -ForegroundColor Red
                pause
                continue
            }
            Activate-Venv
            $v = Read-Host "Versione ADK (0 = latest) [es: 1.6.2]"
            if ($v -eq "0") { $v = "latest" }
            Install-ADK -version $v
            pause
        }
        "4" {
            Write-Host "Uscita script."
            break
        }
        default {
            Write-Host "Opzione non valida."
        }
    }
}
