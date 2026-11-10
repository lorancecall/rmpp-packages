# Install Vellum and the rmpp packages (Korean keyboard, Bluetooth, Tailscale) on a reMarkable Paper Pro.
# Runs on Windows 10/11 (PowerShell 5.1 or 7) with the built-in OpenSSH client.
#
#   irm https://lorancecall.github.io/rmpp-packages/install-rmpp.ps1 -OutFile install-rmpp.ps1
#   powershell -ExecutionPolicy Bypass -File install-rmpp.ps1 [-TabletHost 10.11.99.1]
#
# Before you start, turn on developer mode on the tablet. The root password is shown in
# Settings > General > Help > About > Copyrights and licenses.
param([string]$TabletHost = "")

$ErrorActionPreference = "Stop"
$Repo = "https://lorancecall.github.io/rmpp-packages"
$VellumReadme = "https://raw.githubusercontent.com/vellum-dev/vellum-cli/main/README.md"
$BootstrapUrl = "https://github.com/vellum-dev/vellum-cli/releases/latest/download/bootstrap.sh"
$Packages = "rmpp-korean rmpp-bt rmpp-tailscale"
$Key = Join-Path $HOME ".ssh\id_ed25519_rmpp"

function Say($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Die($m) { Write-Host "`nError: $m" -ForegroundColor Red; exit 1 }
foreach ($c in "ssh", "ssh-keygen") {
    if (-not (Get-Command $c -ErrorAction SilentlyContinue)) { Die "$c is not installed (Settings > Apps > Optional features > OpenSSH Client)" }
}

if (-not $TabletHost) {
    $TabletHost = Read-Host "Tablet address [10.11.99.1 over USB, or its Wi-Fi IP]"
    if (-not $TabletHost) { $TabletHost = "10.11.99.1" }
}
$Target = "root@$TabletHost"
$SshOpts = @("-i", $Key, "-o", "IdentitiesOnly=yes", "-o", "StrictHostKeyChecking=accept-new")

# Run a command on the tablet; optional text is sent to its standard input.
function Remote([string]$Cmd, [string]$InputText = $null, [switch]$Batch) {
    $opts = $SshOpts
    if ($Batch) { $opts = $opts + @("-o", "BatchMode=yes", "-o", "ConnectTimeout=8") }
    # Out-Host keeps ssh's output out of the return value
    if ($null -ne $InputText) { $InputText | & ssh @opts $Target $Cmd | Out-Host } else { & ssh @opts $Target $Cmd | Out-Host }
    return ($LASTEXITCODE -eq 0)
}

# Feed a local file byte for byte (no line-ending or encoding changes) to a command on the tablet.
function SendFile([string]$LocalPath, [string]$RemoteCmd) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo "ssh"
    $psi.Arguments = "-i `"$Key`" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new $Target `"$RemoteCmd`""
    $psi.RedirectStandardInput = $true
    $psi.UseShellExecute = $false
    $p = [System.Diagnostics.Process]::Start($psi)
    $bytes = [System.IO.File]::ReadAllBytes($LocalPath)
    $p.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
    $p.StandardInput.Close()
    $p.WaitForExit()
    return ($p.ExitCode -eq 0)
}

# 1. SSH key: the password is asked once, then the key is used.
if (-not (Test-Path $Key)) {
    Say "Creating an SSH key for the tablet ($Key)"
    New-Item -ItemType Directory -Force (Split-Path $Key) | Out-Null
    # cmd /c passes the empty passphrase reliably on both PowerShell 5.1 and 7
    cmd /c "ssh-keygen -q -t ed25519 -N `"`" -C rmpp -f `"$Key`""
    if ($LASTEXITCODE -ne 0) { Die "ssh-keygen failed" }
}
if (-not (Remote "true" -Batch)) {
    Say "Logging in to $TabletHost. Type the tablet's root password when asked."
    if (-not (SendFile "$Key.pub" "umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys")) { Die "could not log in to $TabletHost" }
    if (-not (Remote "true" -Batch)) { Die "the key was not accepted" }
}
Say "Logged in to $TabletHost"

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("rmpp-" + [guid]::NewGuid())
New-Item -ItemType Directory $tmp | Out-Null
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 2. Vellum (skipped when already installed). The bootstrap is checked against the hash in Vellum's README.
if (Remote "[ -x /home/root/.vellum/bin/vellum ]") {
    Say "Vellum is already installed"
} else {
    Say "Installing Vellum"
    $boot = Join-Path $tmp "bootstrap.sh"
    Invoke-WebRequest -UseBasicParsing $BootstrapUrl -OutFile $boot
    $readme = (Invoke-WebRequest -UseBasicParsing $VellumReadme).Content
    $want = ([regex]'echo "([0-9a-f]{64})  bootstrap.sh"').Match($readme).Groups[1].Value
    $got = (Get-FileHash $boot -Algorithm SHA256).Hash.ToLower()
    if (-not $want -or $want -ne $got) { Die "Vellum bootstrap checksum mismatch ($got, expected $want)" }
    if (-not (SendFile $boot "cat > /tmp/vellum-bootstrap.sh")) { Die "could not copy the Vellum bootstrap" }
    if (-not (Remote "sh /tmp/vellum-bootstrap.sh; r=`$?; rm -f /tmp/vellum-bootstrap.sh; exit `$r")) { Die "Vellum installation failed" }
}

# 3. This package repository and its signing key (downloaded here, so the tablet needs no TLS certificates).
Say "Adding the rmpp package repository"
$pubKey = Join-Path $tmp "lorancecall-rmpp.rsa.pub"
Invoke-WebRequest -UseBasicParsing "$Repo/lorancecall-rmpp.rsa.pub" -OutFile $pubKey
if (-not (SendFile $pubKey "cat > /home/root/.vellum/etc/apk/keys/lorancecall-rmpp.rsa.pub")) { Die "could not copy the repository key" }
Remote "grep -qxF '$Repo' /home/root/.vellum/etc/apk/repositories || echo '$Repo' >> /home/root/.vellum/etc/apk/repositories" | Out-Null

# 4. Packages. The tablet's screen restarts once or twice while they install.
Say "Installing $Packages (the tablet's screen will restart)"
if (-not (Remote "/home/root/.vellum/bin/vellum update && /home/root/.vellum/bin/vellum add $Packages")) { Die "package installation failed" }

# 5. After a reMarkable OS update the files in the root file system are gone: restore them.
if (Remote "[ ! -x /usr/lib/rmpp-preload/launch ]") {
    Say "Restoring system files after an OS update (vellum reenable)"
    if (-not (Remote "/home/root/.vellum/bin/vellum reenable")) { Die "vellum reenable failed" }
}

Remove-Item -Recurse -Force $tmp
Say "Done. On the tablet: Settings > Language & keyboard > Korean; Settings > Bluetooth."
Write-Host "After a reMarkable OS update, run this script again (it runs 'vellum reenable')."
