# scripts/windows/install_docker.ps1
# Verify/install Docker on Windows:
#   1) Prefer Docker Desktop (Windows). If declined/unavailable, then
#   2) Offer Docker Engine inside WSL (Ubuntu).
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

[CmdletBinding(SupportsShouldProcess=$true, PositionalBinding=$true)]
param(
  [Parameter(Position=0)]
  [string]$InstallRoot,

  [switch]$Yes,
  [switch]$No,
  [switch]$YesWsl,
  [switch]$NoWsl
)

# ---- Guard: conflicting flags ------------------------------------------------
if ($Yes -and $No)       { Write-Error "Cannot use -Yes and -No together."; exit 2 }
if ($YesWsl -and $NoWsl) { Write-Error "Cannot use -YesWsl and -NoWsl together."; exit 2 }

# Prefer TLS 1.2 for downloads on older .NET
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

# Infer repo root from script location (two levels up from /scripts/windows)
if (-not $InstallRoot -or [string]::IsNullOrWhiteSpace($InstallRoot)) {
  try { $InstallRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
  catch { $InstallRoot = (Get-Location).Path }
}

function Test-IsAdmin {
  try {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal $id
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  } catch { return $false }
}

function Prompt-YesNo([string]$Message, [bool]$DefaultYes = $true) {
  # Always return a strict [bool]
  $suffix = if ($DefaultYes) { "[Y]/n" } else { "y/[N]" }
  while ($true) {
    $resp = Read-Host "$Message $suffix"
    if ([string]::IsNullOrWhiteSpace($resp)) { return [bool]$DefaultYes }
    $r = $resp.Trim().ToLowerInvariant()
    if ($r -eq 'y' -or $r -eq 'yes') { return $true }
    if ($r -eq 'n' -or $r -eq 'no')  { return $false }
    Write-Host "[INFO] Please answer 'y' or 'n'."
  }
}

function Test-DockerReady {
  $docker = Get-Command docker -ErrorAction SilentlyContinue
  if (-not $docker) { return $false }

  & docker info *> $null
  if ($LASTEXITCODE -ne 0) { return $false }

  & docker compose version *> $null
  if ($LASTEXITCODE -ne 0) { return $false }

  return $true
}

function Test-DockerDesktopPresent {
  $paths = @()
  if ($env:ProgramFiles)        { $paths += (Join-Path $env:ProgramFiles            "Docker\Docker\Docker Desktop.exe") }
  if ($env:LOCALAPPDATA)        { $paths += (Join-Path $env:LOCALAPPDATA            "Docker\Docker Desktop.exe") }
  $pf86 = [Environment]::GetFolderPath('ProgramFilesX86')
  if ($pf86)                    { $paths += (Join-Path $pf86                         "Docker\Docker\Docker Desktop.exe") }
  $existing = $paths | Where-Object { Test-Path $_ }
  return ($existing.Count -gt 0)
}

function Install-DockerDesktop {
  Write-Host "[INFO] Docker Desktop not detected or incomplete. Installing Docker Desktop..."

  $candidateUrls = @(
    "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe",
    "https://desktop.docker.com/win/stable/Docker%20Desktop%20Installer.exe"
  )

  $installerPath = Join-Path $env:TEMP "DockerDesktopInstaller.exe"
  $downloaded = $false
  foreach ($u in $candidateUrls) {
    Write-Host "[INFO] Downloading: $u"
    try {
      Invoke-WebRequest -Uri $u -OutFile $installerPath -UseBasicParsing -ErrorAction Stop
      $downloaded = $true
      break
    } catch {
      # IMPORTANT: use ${u} to avoid "$u:" scope parse issue
      Write-Host "[WARN] Download failed from ${u}: $($_.Exception.Message)"
    }
  }
  if (-not $downloaded) {
    Write-Host "[ERROR] Failed to download Docker Desktop from all sources."
    return $false
  }

  Write-Host "[INFO] Running silent installer (this may trigger UAC)..."
  try {
    $p = Start-Process -FilePath $installerPath -ArgumentList @("install","--quiet") -Verb RunAs -PassThru -Wait
    if ($p.ExitCode -ne 0) {
      Write-Host "[ERROR] Installer returned exit code $($p.ExitCode)."
      return $false
    }
  } catch {
    Write-Host "[ERROR] Failed to run Docker Desktop installer: $($_.Exception.Message)"
    return $false
  } finally {
    try { Remove-Item $installerPath -Force -ErrorAction SilentlyContinue } catch {}
  }

  # Ensure local group 'docker-users' exists and add current user
  $groupName = "docker-users"
  $currentAccount = ([Security.Principal.WindowsIdentity]::GetCurrent().Name)

  Write-Host "[INFO] Ensuring local group '$groupName' exists..."
  try {
    $null = Get-LocalGroup -Name $groupName -ErrorAction Stop
  } catch {
    Write-Host "[INFO] Creating group '$groupName'..."
    try {
      $null = Start-Process -FilePath "cmd.exe" -ArgumentList "/c","net","localgroup",$groupName,"/add" -Verb RunAs -Wait -PassThru
    } catch {
      Write-Host "[WARN] Could not create group using 'net': $($_.Exception.Message)"
    }
  }

  Write-Host "[INFO] Adding user '$currentAccount' to '$groupName' (may prompt for UAC)..."
  try {
    if (Test-IsAdmin) {
      try { Add-LocalGroupMember -Group $groupName -Member $currentAccount -ErrorAction Stop } catch {
        $null = Start-Process -FilePath "cmd.exe" -ArgumentList "/c","net","localgroup",$groupName,$currentAccount,"/add" -Verb RunAs -Wait -PassThru
      }
    } else {
      $null = Start-Process -FilePath "cmd.exe" -ArgumentList "/c","net","localgroup",$groupName,$currentAccount,"/add" -Verb RunAs -Wait -PassThru
    }
  } catch {
    Write-Host "[WARN] Could not add user to '$groupName': $($_.Exception.Message)"
  }

  Write-Host "[INFO] Waiting a few seconds and probing Docker..."
  Start-Sleep -Seconds 5

  return (Test-DockerReady)
}

function Test-WslAvailable {
  $wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
  if (-not $wsl) { return $false }
  try { $null = wsl -l -q 2>$null; return $true } catch { return $false }
}

function Get-WslDistros {
  try {
    (wsl -l -q 2>$null) | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 }
  } catch { @() }
}

function Get-PreferredWslDistro {
  $distros = @(Get-WslDistros)
  if ($distros.Count -eq 0) { return $null }
  $ubuntu = $distros | Where-Object { $_ -match '^Ubuntu' } | Select-Object -First 1
  if ($ubuntu) { return $ubuntu }
  return $distros[0]
}

function Test-WslDockerInstalled([string]$Distro) {
  if ([string]::IsNullOrWhiteSpace($Distro)) { return $false }
  $cmd = 'command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1'
  & wsl -d $Distro -- bash -lc $cmd 2>$null | Out-Null
  return ($LASTEXITCODE -eq 0)
}

function Test-WslDockerDaemonReady([string]$Distro) {
  if ([string]::IsNullOrWhiteSpace($Distro)) { return $false }
  $cmd = 'docker info >/dev/null 2>&1'
  & wsl -d $Distro -- bash -lc $cmd 2>$null | Out-Null
  return ($LASTEXITCODE -eq 0)
}

function Install-WslUbuntu {
  Write-Host "[INFO] WSL is missing Ubuntu. Attempting to install Ubuntu..."
  try {
    Start-Process -FilePath "wsl.exe" -ArgumentList @("--install","-d","Ubuntu") -Verb RunAs
    Write-Host "[INFO] The WSL/Ubuntu installation has been initiated by Windows. A reboot or first-run user setup may be required."
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
  - Install Docker from the official Docker apt repository (with fallback to Ubuntu packages)
  - Add your Linux user to the 'docker' group
  - Shut down WSL to apply changes (you may need to reopen WSL)
"@ | Write-Host

  $linuxScript = @'
set -euo pipefail

echo "[WSL] Checking/Enabling systemd in /etc/wsl.conf"
if ! grep -q "^systemd=true" /etc/wsl.conf 2>/dev/null; then
  printf "\n[boot]\nsystemd=true\n" | sudo tee -a /etc/wsl.conf >/dev/null
  echo "[WSL] Enabled systemd=true in /etc/wsl.conf (takes effect after wsl --shutdown)"
fi

echo "[WSL] Installing Docker from official repo (with fallback)..."
set +e
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg lsb-release
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
codename="$(. /etc/os-release && echo "${VERSION_CODENAME:-$(lsb_release -cs)}")"
arch="$(dpkg --print-architecture)"
echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${codename} stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
rc=$?
if [ "$rc" -ne 0 ]; then
  echo "[WSL] Official Docker repo install failed (rc=$rc), falling back to Ubuntu packages..."
  sudo apt-get update -y
  sudo apt-get install -y docker.io docker-compose-plugin
fi
set -e

linux_user="${SUDO_USER:-$USER}"
if id -nG "$linux_user" | tr " " "\n" | grep -qx "docker"; then
  echo "[WSL] User $linux_user already in docker group"
else
  sudo usermod -aG docker "$linux_user" || true
  echo "[WSL] Added $linux_user to docker group (sign out/in of WSL to apply)"
fi

if ! (ps -p 1 -o comm= | grep -q systemd); then
  echo "[WSL] systemd not active in this session; attempting to start docker service once..."
  sudo service docker start || true
fi

echo "[WSL] Docker versions:"
docker --version || true
docker compose version || true
'@

  & wsl -d $Distro -- bash -lc $linuxScript
  $exit = $LASTEXITCODE
  if ($exit -ne 0) {
    Write-Host "[ERROR] Failed to provision Docker in WSL (exit code $exit)."
    return $false
  }

  try {
    Write-Host "[INFO] Shutting down WSL to apply systemd/group changes..."
    wsl --shutdown 2>$null
  } catch { }

  Start-Sleep -Seconds 3
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

# --------------------- MAIN ---------------------------------------------------

Write-Host "[INFO] Checking for Docker CLI and Compose v2 availability..."
Write-Host "[INFO] Install root: $InstallRoot"

# 0) If Docker CLI already works on Windows, we are done.
if (Test-DockerReady) {
  Write-Host "[OK] Docker and Docker Compose v2 are already available on Windows."
  docker --version
  docker compose version
  exit 0
}

# 1) Check if Docker Desktop is installed; OFFER to install, but ONLY if user explicitly agrees.
$desktopPresent = Test-DockerDesktopPresent
if (-not $desktopPresent) {
  [bool]$shouldInstallDesktop = $false

  if     ($Yes) { $shouldInstallDesktop = $true  }
  elseif ($No)  { $shouldInstallDesktop = $false }
  else {
    $shouldInstallDesktop = [bool](Prompt-YesNo "Docker Desktop is not installed. Install it now?" $true)
  }

  if (-not $shouldInstallDesktop) {
    Write-Host "[INFO] User declined Docker Desktop. Skipping Desktop installation."
  } else {
    if (Install-DockerDesktop) {
      Write-Host "[OK] Docker Desktop installation appears successful."
      docker --version
      docker compose version
      exit 0
    } else {
      Write-Host "[WARN] Docker Desktop install did not complete successfully."
      # Fall through to WSL option
    }
  }
} else {
  Write-Host "[INFO] Docker Desktop appears to be installed."
  Write-Host "      (If the daemon is not running, start Docker Desktop and retry.)"
}

# 2) Check WSL availability
if (-not (Test-WslAvailable)) {
  Write-Host "[INFO] Windows Subsystem for Linux (WSL) does not appear to be installed/configured."
  $installWsl = if ($No) { $true } else { Prompt-YesNo "Install WSL with Ubuntu now?" $true }
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

# 3) WSL exists. Choose a distro (prefer Ubuntu*)
$distro = Get-PreferredWslDistro
if (-not $distro) {
  Write-Host "[WARN] No WSL distributions found. You can add one with: wsl --install -d Ubuntu"
  exit 0
}

# 4) If Docker already installed in WSL, just surface status/tips
if (Test-WslDockerInstalled -Distro $distro) {
  Write-Host "[OK] Docker CLI & Compose detected in WSL ($distro)."
  & wsl -d $distro -- bash -lc "docker --version && docker compose version"
  if (Test-WslDockerDaemonReady -Distro $distro) {
    Write-Host "[OK] Docker daemon is reachable in WSL."
  } else {
    Write-Host "[WARN] Docker is installed in WSL but the daemon is not reachable right now."
    Write-Host "      Start via systemd or: sudo service docker start"
  }
  Write-Host ""
  Write-Host "[TIP] Run Docker commands inside your WSL distro:"
  Write-Host "      wsl -d $distro docker ps"
  exit 0
}

# 5) Offer to install Docker in WSL
$installWslDocker =
  if     ($YesWsl) { $true }
  elseif ($NoWsl)  { $false }
  else             { Prompt-YesNo "Docker is not installed in WSL ($distro). Install it now?" $true }

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
