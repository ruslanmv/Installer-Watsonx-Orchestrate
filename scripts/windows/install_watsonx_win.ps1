# ===============================
# watsonx ADK Installer (Windows)
# ===============================
# This script provides an interactive menu for:
# 1) Full setup (create/refresh venv + install ADK)
# 2) Create/refresh venv only
# 3) Install/upgrade ADK in the existing venv
# 4) Exit (Y exits; anything else returns to the menu)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Config (paths resolved safely) ---
$RepoRoot    = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$envFile     = Join-Path $RepoRoot '.env'
$venvDir     = Join-Path $RepoRoot 'venv'
$adkVersions = @('1.5.0','1.5.1','1.6.0','1.6.1','1.6.2','1.7.0', '1.8.0', '1.14.1')

# --- Helpers ---
function CommandExists {
    param([Parameter(Mandatory)][string]$Name)
    try { Get-Command $Name -ErrorAction Stop | Out-Null; return $true } catch { return $false }
}

function Pause-ForUser {
    param([string]$Message = 'Press ENTER to continue...')
    [void](Read-Host $Message)
}

# Prefer the Python launcher when available for consistent versioning
function Get-PythonForVenv {
    if (CommandExists 'py')      { return 'py' }
    if (CommandExists 'python')  { return 'python' }
    if (CommandExists 'python3') { return 'python3' }
    throw "No Python interpreter found. Please install Python 3.11+."
}

# Load .env into current session (process scope)
function Load-DotEnv {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Host "'.env' not found: $Path" -ForegroundColor Red
        throw "Missing .env"
    }

    Write-Host "Loading environment from: $Path`n"
    Get-Content -LiteralPath $Path | ForEach-Object {
        $line = $_.Trim()
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) { return }

        if ($line -notmatch '=') {
            Write-Host "Ignored (no '='): $line" -ForegroundColor Yellow
            return
        }

        $name,$value = $line -split '=',2
        $name  = $name.Trim()
        $value = $value.Trim()

        # Strip surrounding quotes if present
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

# Create (or recreate) venv
function Create-Venv {
    if (Test-Path -LiteralPath $venvDir) {
        Write-Host "A virtual environment already exists: $venvDir"
        do {
            $choice = Read-Host "Choose: Reuse (1), Recreate (2), or Return to menu (3)"
        } until ($choice -in @('1','2','3'))

        switch ($choice) {
            '1' { return }
            '2' {
                try {
                    Write-Host "Removing existing virtual environment..."
                    Remove-Item -Recurse -Force -LiteralPath $venvDir
                } catch {
                    Write-Host "Failed to remove venv: $($_.Exception.Message)" -ForegroundColor Red
                    throw
                }
            }
            '3' { return }
        }
    }

    $py = Get-PythonForVenv
    Write-Host "Creating virtual environment in '$venvDir'..."
    if ($py -eq 'py') {
        # Prefer Python 3.11 via launcher; fall back to default
        try {
            & py -3.11 -m venv $venvDir
        } catch {
            Write-Host "Falling back to default Python via launcher..." -ForegroundColor Yellow
            & py -m venv $venvDir
        }
    } else {
        & $py -m venv $venvDir
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Virtual environment creation failed. Please verify your Python installation." -ForegroundColor Red
        throw "venv creation failed"
    }
}

# Return venv's Python, or a reasonable fallback
function Get-VenvPython {
    $vp = Join-Path $venvDir 'Scripts\python.exe'
    if (Test-Path -LiteralPath $vp) { return $vp }
    if (CommandExists 'py')      { return 'py' }
    if (CommandExists 'python')  { return 'python' }
    if (CommandExists 'python3') { return 'python3' }
    throw "No Python interpreter found."
}

# “Activate” note (we cannot change the caller’s session from a script)
function Show-ActivateHint {
    $activateScript = Join-Path $venvDir 'Scripts\Activate.ps1'
    if (!(Test-Path -LiteralPath $activateScript)) {
        Write-Host "Activation script not found: $activateScript" -ForegroundColor Yellow
        return
    }
    Write-Host "To activate the virtual environment in your shell:"
    Write-Host "  `"$activateScript`""
    Write-Host "(This installer will continue by invoking the venv’s Python directly.)"
}

# Install or upgrade ADK with the selected Python
function Install-ADK {
    param([string]$Version = 'latest')

    $py = Get-VenvPython
    Write-Host "Using Python: $py"

    Write-Host "Upgrading pip..."
    & $py -m pip install --upgrade pip
    if ($LASTEXITCODE -ne 0) {
        Write-Host "pip upgrade failed." -ForegroundColor Red
        throw "pip upgrade failed"
    }

    if ($Version -eq 'latest') {
        Write-Host "Installing watsonx Orchestrate ADK (latest)..."
        & $py -m pip install --upgrade ibm-watsonx-orchestrate
    } else {
        Write-Host "Installing watsonx Orchestrate ADK ($Version)..."
        & $py -m pip install "ibm-watsonx-orchestrate==$Version"
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ADK installation failed." -ForegroundColor Red
        throw "ADK install failed"
    }
    Write-Host "ADK installation completed." -ForegroundColor Green
}

function Prompt-ADKVersion {
    Write-Host ""
    Write-Host "Available ADK versions:" -ForegroundColor Cyan
    $i = 1
    foreach ($v in $adkVersions) {
        Write-Host ("  {0}) {1}" -f $i, $v)
        $i++
    }
    Write-Host "  0) latest (recommended)"

    $sel = Read-Host "Select a version (0..$($adkVersions.Count))"
    if ([string]::IsNullOrWhiteSpace($sel) -or $sel -eq '0') { return 'latest' }

    if ($sel -as [int] -and $sel -ge 1 -and $sel -le $adkVersions.Count) {
        return $adkVersions[$sel-1]
    }

    # Allow direct semver entry
    return $sel.Trim()
}

# Menu UI
function Show-Menu {
    Clear-Host
    Write-Host ""
    Write-Host "=====================================" -ForegroundColor DarkCyan
    Write-Host " watsonx ADK Installer (Windows)     " -ForegroundColor Cyan
    Write-Host " Repository: $RepoRoot               " -ForegroundColor DarkGray
    Write-Host "=====================================" -ForegroundColor DarkCyan
    Write-Host " 1) Full setup (venv + ADK)"
    Write-Host " 2) Virtual env only"
    Write-Host " 3) Install/Update ADK"
    Write-Host " 4) Exit"
}

# =================
#       MAIN
# =================
while ($true) {
    try {
        Show-Menu
        $option = Read-Host "`nChoose an option (1-4)"

        switch ($option) {
            '1' {
                # Full setup
                Load-DotEnv -Path $envFile
                Create-Venv
                Show-ActivateHint

                $ver = Prompt-ADKVersion
                Install-ADK -Version $ver

                Write-Host "`nDone. Activate the environment with:" -ForegroundColor Green
                Write-Host "  .\venv\Scripts\Activate.ps1"
                Pause-ForUser
            }
            '2' {
                # venv only
                Create-Venv
                Write-Host "`nVirtual environment is ready. Activate with:" -ForegroundColor Green
                Write-Host "  .\venv\Scripts\Activate.ps1"
                Pause-ForUser
            }
            '3' {
                # ADK install/update
                if (!(Test-Path -LiteralPath $venvDir)) {
                    Write-Host "No virtual environment found." -ForegroundColor Yellow
                    $ans = Read-Host "Create one now? (Y/n)"
                    if ($ans -match '^(?i)n(o)?$') {
                        continue
                    }
                    Create-Venv
                }
                Show-ActivateHint
                $ver = Prompt-ADKVersion
                Install-ADK -Version $ver
                Pause-ForUser
            }
            '4' {
                # Exit with confirmation: Y exits; anything else returns to menu
                $confirm = Read-Host "Exit the installer? (y/N)"
                if ($confirm -match '^(?i)y(es)?$') {
                    Write-Host "`nExiting..." -ForegroundColor Cyan
                    exit 0
                } else {
                    continue
                }
            }
            default {
                Write-Host "Invalid option. Please enter 1, 2, 3 or 4." -ForegroundColor Yellow
                Start-Sleep -Milliseconds 900
            }
        }
    } catch {
        Write-Host ""
        Write-Host "An error occurred: $($_.Exception.Message)" -ForegroundColor Red
        Pause-ForUser
    }
}
