# scripts/windows/install_docker.ps1
# Install/verify Docker Desktop for Windows and Docker Compose v2 (ASCII-only output)

# Use TLS 1.2 for downloads on older .NET
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

Write-Host "[INFO] Checking for Docker Desktop and Compose v2..."

function Test-DockerReady {
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if (-not $docker) { return $false }
    try {
        $null = docker version --format '{{.Server.Version}}' 2>$null
    } catch { return $false }
    try {
        $null = docker compose version 2>$null
    } catch { return $false }
    return $true
}

if (Test-DockerReady) {
    Write-Host "[OK] Docker and Docker Compose v2 are already installed."
    docker --version
    docker compose version
    exit 0
}

Write-Host "[INFO] Docker Desktop not detected or incomplete. Installing Docker Desktop..."

# Download Docker Desktop installer
$installerUrl  = "https://desktop.docker.com/win/stable/Docker%20Desktop%20Installer.exe"
$installerPath = Join-Path $env:TEMP "DockerInstaller.exe"

Write-Host "[INFO] Downloading: $installerUrl"
try {
    Invoke-WebRequest -UseBasicParsing -Uri $installerUrl -OutFile $installerPath
} catch {
    Write-Host "[ERROR] Failed to download Docker Desktop: $($_.Exception.Message)"
    exit 1
}

# Silent install
Write-Host "[INFO] Running silent installer..."
$arguments = @("install", "--quiet")
try {
    $p = Start-Process -FilePath $installerPath -ArgumentList $arguments -PassThru -Wait -NoNewWindow
    if ($p.ExitCode -ne 0) {
        Write-Host "[ERROR] Installer returned exit code $($p.ExitCode)."
        exit 1
    }
} catch {
    Write-Host "[ERROR] Failed to run Docker installer: $($_.Exception.Message)"
    exit 1
} finally {
    try { Remove-Item $installerPath -Force -ErrorAction SilentlyContinue } catch {}
}

# Ensure local group 'docker-users' exists and add current user
$groupName   = "docker-users"
$currentUser = "$($env:USERDOMAIN)\$($env:USERNAME)"

Write-Host "[INFO] Ensuring local group '$groupName' exists..."
try {
    $group = Get-LocalGroup -Name $groupName -ErrorAction Stop
} catch {
    Write-Host "[INFO] Creating group '$groupName'..."
    try { net localgroup $groupName /add | Out-Null } catch { Write-Host "[WARN] Could not create group using 'net': $($_.Exception.Message)" }
}

Write-Host "[INFO] Adding user '$currentUser' to '$groupName'..."
try {
    # Prefer PowerShell cmdlet when available
    Add-LocalGroupMember -Group $groupName -Member $currentUser -ErrorAction Stop
} catch {
    # Fallback to 'net' if Add-LocalGroupMember not available or fails
    try { net localgroup $groupName $currentUser /add | Out-Null } catch { Write-Host "[WARN] Could not add user using 'net': $($_.Exception.Message)" }
}

# Final checks
Write-Host "[INFO] Waiting a few seconds and probing Docker..."
Start-Sleep -Seconds 5

if (Test-DockerReady) {
    Write-Host "[OK] Docker Desktop installation appears successful."
    docker --version
    docker compose version
} else {
    Write-Host "[WARN] Docker may require a logoff or reboot before it is ready."
}

Write-Host ""
Write-Host "[NEXT STEPS]"
Write-Host "  1) If Docker is not responding yet, restart Windows or sign out/in."
Write-Host "  2) After restart, verify with:"
Write-Host "       docker --version"
Write-Host "       docker compose version"
Write-Host ""
Write-Host "[DONE] Docker Desktop install script finished."
