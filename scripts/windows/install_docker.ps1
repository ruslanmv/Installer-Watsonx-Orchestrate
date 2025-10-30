# scripts/windows/install_docker.ps1
# Verify/install Docker on Windows:
#  1) Prefer Docker Desktop (Windows). If user declines, then
#  2) Check Docker Engine in WSL and offer to install it (Ubuntu).
#
# ASCII-only output, interactive by default. Optional switches:
#   -Yes        -> auto-yes to Docker Desktop install prompt
#   -No         -> auto-no to Desktop (will ask about WSL)
#   -YesWsl     -> auto-yes to WSL Docker install prompt (used if Desktop is skipped)
#   -NoWsl      -> auto-no to WSL Docker install prompt
#
# Examples:
#   powershell -ExecutionPolicy Bypass -File scripts/windows/install_docker.ps1
#   powershell -ExecutionPolicy Bypass -File scripts/windows/install_docker.ps1 -No -YesWsl

[CmdletBinding()]
param(
  # Optional positional repo/install root passed by Makefile
  [Parameter(Position=0)]
  [string]$InstallRoot,

  [switch]$Yes,
  [switch]$No,
  [switch]$YesWsl,
  [switch]$NoWsl
)

# If not provided, infer repo root from script location (two levels up from /scripts/windows)
if (-not $InstallRoot -or [string]::IsNullOrWhiteSpace($InstallRoot)) {
  try {
    $InstallRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  } catch {
    $InstallRoot = (Get-Location).Path
  }
}

# Use TLS 1.2 for downloads on older .NET
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

Write-Host "[INFO] Checking for Docker CLI and Compose v2 availability..."
Write-Host "[INFO] Install root: $InstallRoot"

function Test-DockerReady {
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $docker) { return $false }
    try {
        # Requires reachable daemon
        $null = docker info 2>$null
        $null = docker compose version 2>$null
    } catch { return $false }
    return $true
}

function Test-DockerDesktopPresent {
    $paths = @(
        (Join-Path $env:ProgramFiles "Docker\Docker\Docker Desktop.exe")
        (Join-Path $env:LocalAppData "Docker\Docker Desktop.exe")
    )
    foreach ($p in $paths) {
        if (Test-Path $p) { return $true }
    }
    return $false
}

function Prompt-YesNo([string]$Message, [bool]$DefaultYes = $true) {
    # Returns $true for yes, $false for no
    $suffix = if ($DefaultYes) { "[Y]/n" } else { "y/[N]" }
    while ($true) {
        $resp = Read-Host "$Message $suffix"
        if ([string]::IsNullOrWhiteSpace($resp)) { return $DefaultYes }
        switch -regex ($resp.Trim()) {
            '^(y|yes)$' { return $true }
            '^(n|no)$'  { return $false }
            default     { Write-Host "[INFO] Please answer 'y' or 'n'." }
        }
    }
}

function Install-DockerDesktop {
    Write-Host "[INFO] Docker Desktop not detected or incomplete. Installing Docker Desktop..."

    $installerUrl  = "https://desktop.docker.com/win/stable/Docker%20Desktop%20Installer.exe"
    $installerPath = Join-Path $env:TEMP "DockerInstaller.exe"

    Write-Host "[INFO] Downloading: $installerUrl"
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $installerUrl -OutFile $installerPath
    } catch {
        Write-Host "[ERROR] Failed to download Docker Desktop: $($_.Exception.Message)"
        return $false
    }

    Write-Host "[INFO] Running silent installer..."
    $arguments = @("install", "--quiet")
    try {
        $p = Start-Process -FilePath $installerPath -ArgumentList $arguments -PassThru -Wait -NoNewWindow
        if ($p.ExitCode -ne 0) {
            Write-Host "[ERROR] Installer returned exit code $($p.ExitCode)."
            return $false
        }
    } catch {
        Write-Host "[ERROR] Failed to run Docker installer: $($_.Exception.Message)"
        return $false
    } finally {
        try { Remove-Item $installerPath -Force -ErrorAction SilentlyContinue } catch {}
    }

    # Ensure local group 'docker-users' exists and add current user
    $groupName   = "docker-users"
    $currentUser = "$($env:USERDOMAIN)\$($env:USERNAME)"

    Write-Host "[INFO] Ensuring local group '$groupName' exists..."
    try {
        $null = Get-LocalGroup -Name $groupName -ErrorAction Stop
    } catch {
        Write-Host "[INFO] Creating group '$groupName'..."
        try { net localgroup $groupName /add | Out-Null } catch { Write-Host "[WARN] Could not create group using 'net': $($_.Exception.Message)" }
    }

    Write-Host "[INFO] Adding user '$currentUser' to '$groupName'..."
    try {
        Add-LocalGroupMember -Group $groupName -Member $currentUser -ErrorAction Stop
    } catch {
        try { net localgroup $groupName $currentUser /add | Out-Null } catch { Write-Host "[WARN] Could not add user using 'net': $($_.Exception.Message)" }
    }

    # Give Desktop a moment to settle
    Write-Host "[INFO] Waiting a few seconds and probing Docker..."
    Start-Sleep -Seconds 5
    return (Test-DockerReady)
}

function Test-WslAvailable {
    $wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
    if (-not $wsl) { return $false }
    try {
        $null = wsl -l -q 2>$null
        return $true
    } catch { return $false }
}

function Get-WslDistros {
    try {
        (wsl -l -q 2>$null) | Where-Object { $_ -and $_.Trim().Length -gt 0 }
    } catch { @() }
}

function Get-PreferredWslDistro {
    $distros = @(Get-WslDistros)
    if ($distros.Count -eq 0) { return $null }
    if ($distros -contains "Ubuntu") { return "Ubuntu" }
    return $distros[0]
}

# ---- NEW: split installed vs daemon-ready checks for WSL ----
function Test-WslDockerInstalled([string]$Distro) {
    if ([string]::IsNullOrWhiteSpace($Distro)) { return $false }
    # Only check CLI + compose presence (no daemon)
    $cmd = 'command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1'
    & wsl -d $Distro -- bash -lc $cmd 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Test-WslDockerDaemonReady([string]$Distro) {
    if ([string]::IsNullOrWhiteSpace($Distro)) { return $false }
    # Requires reachable daemon
    $cmd = 'docker info >/dev/null 2>&1'
    & wsl -d $Distro -- bash -lc $cmd 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Install-WslUbuntu {
    Write-Host "[INFO] WSL is missing Ubuntu. Attempting to install Ubuntu..."
    try {
        Start-Process -FilePath "wsl.exe" -ArgumentList @("--install","-d","Ubuntu") -Verb RunAs
        Write-Host "[INFO] The WSL/Ubuntu installation has been initiated by Windows. A reboot or user setup may be required."
        return $true
    } catch {
        Write-Host "[ERROR] Failed to initiate WSL/Ubuntu installation: $($_.Exception.Message)"
        return $false
    }
}

function Install-WslDocker([string]$Distro) {
    Write-Host "[INFO] Installing Docker Engine and Compose plugin inside WSL ($Distro)..."
@"
This will:
  - Enable systemd in /etc/wsl.conf (if not already)
  - Install: docker.io and docker-compose-plugin
  - Add your Linux user to the 'docker' group
  - Shut down WSL to apply changes (you may need to restart WSL)
"@ | Write-Host

    $linuxScript = @'
set -e
if [ ! -f /etc/wsl.conf ] || ! grep -q "^systemd=true" /etc/wsl.conf 2>/dev/null; then
  sudo mkdir -p /etc
  printf "[boot]\nsystemd=true\n" | sudo tee /etc/wsl.conf >/dev/null
  echo "[WSL] Enabled systemd in /etc/wsl.conf"
fi
sudo apt-get update -y
sudo apt-get install -y docker.io docker-compose-plugin
# Add user to docker group (won't take effect until re-login)
if id -nG "$USER" | tr " " "\n" | grep -qx "docker"; then
  echo "[WSL] User $USER already in docker group"
else
  sudo usermod -aG docker "$USER" || true
  echo "[WSL] Added $USER to docker group (sign out/in of WSL to apply)"
fi
# Try to start the daemon for the current session if systemd not yet active
if ! (ps -p 1 -o comm= | grep -q systemd); then
  sudo service docker start || true
fi
'@

    & wsl -d $Distro -- bash -lc $linuxScript
    $exit = $LASTEXITCODE
    if ($exit -ne 0) {
        Write-Host "[ERROR] Failed to provision Docker in WSL (exit code $exit)."
        return $false
    }

    # Restart WSL to pick up systemd changes (safe to do from Windows)
    try {
        Write-Host "[INFO] Shutting down WSL to apply systemd/group changes..."
        wsl --shutdown 2>$null
    } catch { }

    # Re-probe
    Start-Sleep -Seconds 3
    # Launch once so systemd can start services
    & wsl -d $Distro -- bash -lc "true" 2>$null | Out-Null
    Start-Sleep -Seconds 2

    if (Test-WslDockerInstalled -Distro $Distro) {
        Write-Host "[OK] Docker CLI and Compose detected inside WSL."
        if (Test-WslDockerDaemonReady -Distro $Distro) {
            & wsl -d $Distro -- bash -lc "docker --version && docker compose version"
            return $true
        } else {
            Write-Host "[WARN] Docker installed in WSL, but daemon not running yet. Reopen WSL terminal or reboot."
            return $true
        }
    } else {
        Write-Host "[WARN] Docker in WSL not detected after install steps."
        return $false
    }
}

# --------------------- MAIN LOGIC ---------------------

# 0) If Docker CLI already works on Windows, we are done.
if (Test-DockerReady) {
    Write-Host "[OK] Docker and Docker Compose v2 are already available on Windows."
    docker --version
    docker compose version
    exit 0
}

# 1) Check if Docker Desktop is installed; offer to install
$desktopPresent = Test-DockerDesktopPresent
if (-not $desktopPresent) {
    $installDesktop = $false
    if ($Yes) {
        $installDesktop = $true
    } elseif ($No) {
        $installDesktop = $false
    } else {
        $installDesktop = Prompt-YesNo "Docker Desktop is not installed. Install it now?" $true
    }

    if ($installDesktop) {
        if (Install-DockerDesktop) {
            Write-Host "[OK] Docker Desktop installation appears successful."
            docker --version
            docker compose version
            exit 0
        } else {
            Write-Host "[WARN] Docker Desktop install did not complete successfully."
            # Fall through to WSL option just in case
        }
    } else {
        Write-Host "[INFO] Skipping Docker Desktop installation per user choice."
    }
} else {
    Write-Host "[INFO] Docker Desktop appears to be installed."
    Write-Host "      (If the daemon isn't running, start Docker Desktop and retry.)"
}

# At this point, Desktop is either skipped or not working. Offer/verify WSL option.

# 2) Check WSL availability
if (-not (Test-WslAvailable)) {
    Write-Host "[INFO] Windows Subsystem for Linux (WSL) does not appear to be installed/configured."
    $installWsl = if ($No) { $true } else {  # If user said 'No' to Desktop, default to offering WSL
        Prompt-YesNo "Install WSL with Ubuntu now?" $true
    }

    if ($installWsl) {
        if (Install-WslUbuntu) {
            Write-Host "[NEXT STEPS] Complete Ubuntu first-run setup if prompted, then re-run this script to install Docker in WSL."
        } else {
            Write-Host "[ERROR] Could not initiate WSL installation. Please install WSL/Ubuntu manually and re-run."
        }
    } else {
        Write-Host "[INFO] Skipping WSL installation. Docker will not be available."
    }
    exit 0
}

# 3) WSL exists. Check default/Ubuntu distro for Docker.
$distro = Get-PreferredWslDistro
if (-not $distro) {
    Write-Host "[WARN] No WSL distributions found. You can add one with: wsl --install -d Ubuntu"
    exit 0
}

# ---- FIXED: first check if Docker is installed in WSL (no daemon required) ----
if (Test-WslDockerInstalled -Distro $distro) {
    Write-Host "[OK] Docker CLI & Compose detected in WSL ($distro)."
    & wsl -d $distro -- bash -lc "docker --version && docker compose version"
    if (Test-WslDockerDaemonReady -Distro $distro) {
        Write-Host "[OK] Docker daemon is reachable in WSL."
    } else {
        Write-Host "[WARN] Docker is installed in WSL but the daemon isn't reachable right now."
        Write-Host "      Start it via systemd or: sudo service docker start"
    }
    Write-Host ""
    Write-Host "[TIP] Run Docker commands inside your WSL distro:"
    Write-Host "      wsl -d $distro docker ps"
    exit 0
}

# 4) Docker not installed in WSL. Offer to install Docker Engine in WSL.
$installWslDocker = if ($YesWsl) { $true } elseif ($NoWsl) { $false } else {
    Prompt-YesNo "Docker is not installed in WSL ($distro). Install it now?" $true
}

if ($installWslDocker) {
    if (Install-WslDocker -Distro $distro) {
        Write-Host "[DONE] WSL Docker installation completed."
        exit 0
    } else {
        Write-Host "[WARN] WSL Docker installation did not complete successfully."
        exit 1
    }
} else {
    Write-Host "[INFO] Skipping Docker installation in WSL. Docker will not be available."
    exit 0
}
