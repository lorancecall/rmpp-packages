# Install Vellum and the rmpp packages on a reMarkable Paper Pro. A checkbox menu lets you pick the packages
# (Korean keyboard, Bluetooth, Tailscale); the menu and messages are in Korean or English (L switches).
# Runs on Windows 10/11 (PowerShell 5.1 or 7) with the built-in OpenSSH client.
#
#   irm https://lorancecall.github.io/rmpp-packages/install-rmpp.ps1 -OutFile install-rmpp.ps1
#   powershell -ExecutionPolicy Bypass -File install-rmpp.ps1 [-TabletHost 10.11.99.1] [-Lang ko|en]
#                                                             [-Packages rmpp-korean,rmpp-bt] [-Yes]
#
#   -Packages  install these without the menu
#   -Yes       no menu: install every package (or the -Packages list)
#
# Before you start, turn on developer mode on the tablet. The root password is shown in
# Settings > General > Help > About > Copyrights and licenses.
# (Saved as UTF-8 with BOM so that Windows PowerShell 5.1 reads the Korean text correctly.)
param([string]$TabletHost = "", [string]$Lang = "", [string[]]$Packages = @(), [switch]$Yes)

$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$Repo = "https://lorancecall.github.io/rmpp-packages"
$VellumReadme = "https://raw.githubusercontent.com/vellum-dev/vellum-cli/main/README.md"
$BootstrapUrl = "https://github.com/vellum-dev/vellum-cli/releases/latest/download/bootstrap.sh"
$All = @("rmpp-korean", "rmpp-bt", "rmpp-tailscale")
$Key = Join-Path $HOME ".ssh\id_ed25519_rmpp"
if (-not $Lang) { $Lang = if ((Get-Culture).Name -like "ko*") { "ko" } else { "en" } }

# ---------------------------------------------------------------- messages (Korean / English)
$Text = @{
    ko = @{
        missing = "가 설치되어 있지 않습니다 (설정 > 앱 > 선택적 기능 > OpenSSH 클라이언트)"
        address = "태블릿 주소 [USB는 10.11.99.1, 또는 Wi-Fi IP]"
        newkey = "태블릿용 SSH 키를 만듭니다"
        password = "에 로그인합니다. 태블릿의 root 비밀번호를 입력하세요."
        nologin = "에 로그인할 수 없습니다"
        nokey = "키가 받아들여지지 않았습니다"
        loggedin = "로그인했습니다:"
        vellum_ok = "Vellum이 이미 설치되어 있습니다"
        vellum = "Vellum을 설치합니다"
        checksum = "Vellum bootstrap 체크섬이 맞지 않습니다"
        vellum_fail = "Vellum 설치에 실패했습니다"
        repo = "rmpp 패키지 저장소를 추가합니다"
        installing = "설치합니다 (태블릿 화면이 한두 번 다시 시작됩니다):"
        install_fail = "패키지 설치에 실패했습니다"
        nothing = "선택한 패키지가 없습니다. 저장소만 추가했습니다."
        reenable = "OS 업데이트 뒤의 시스템 파일을 복구합니다 (vellum reenable)"
        reenable_fail = "vellum reenable에 실패했습니다"
        cancel = "취소했습니다."
        done = "완료. 태블릿에서: 설정 > 언어 및 키보드 > 한국어, 설정 > 블루투스, 설정 > Tailscale."
        again = "reMarkable OS를 업데이트한 뒤에는 이 스크립트를 다시 실행하세요 (vellum reenable을 실행합니다)."
        remove = "제거:"
        title = "설치할 기능을 고르세요"
        keys = "↑↓ 이동   Space 선택   L English   Enter 설치   Q 취소"
        installed = "(설치됨)"
        "rmpp-korean" = "한글 입력: 화면 키보드 한국어 자판과 글꼴, 블루투스·USB·Type Folio 키보드로 한글 입력 (Ctrl+Space 또는 오른쪽 Alt로 전환), 서식 막대의 한/EN 표시"
        "rmpp-bt" = "블루투스: 설정 > 블루투스 (검색, 페어링, 연결, 삭제), 빠른 설정 토글, 부팅할 때 자동으로 켜짐, 키보드별 Type Folio 모드"
        "rmpp-tailscale" = "Tailscale: 설정 > Tailscale (켜기/끄기, QR 코드 로그인, 상태와 기기 목록, 업데이트), 어디서나 Tailscale로 SSH 접속 (/home에 약 70 MB)"
    }
    en = @{
        missing = " is not installed (Settings > Apps > Optional features > OpenSSH Client)"
        address = "Tablet address [10.11.99.1 over USB, or its Wi-Fi IP]"
        newkey = "Creating an SSH key for the tablet"
        password = ": logging in. Type the tablet's root password when asked."
        nologin = ": could not log in"
        nokey = "the key was not accepted"
        loggedin = "Logged in to"
        vellum_ok = "Vellum is already installed"
        vellum = "Installing Vellum"
        checksum = "Vellum bootstrap checksum mismatch"
        vellum_fail = "Vellum installation failed"
        repo = "Adding the rmpp package repository"
        installing = "Installing (the tablet's screen restarts once or twice):"
        install_fail = "package installation failed"
        nothing = "No package selected; only the repository was added."
        reenable = "Restoring system files after an OS update (vellum reenable)"
        reenable_fail = "vellum reenable failed"
        cancel = "Cancelled."
        done = "Done. On the tablet: Settings > Language & keyboard > Korean; Settings > Bluetooth; Settings > Tailscale."
        again = "After a reMarkable OS update, run this script again (it runs 'vellum reenable')."
        remove = "Remove with:"
        title = "Choose what to install"
        keys = "↑↓ move   Space toggle   L 한국어   Enter install   Q quit"
        installed = "(installed)"
        "rmpp-korean" = "Korean input: on-screen Hangul keyboard and fonts; type Korean on Bluetooth/USB/Type Folio keyboards (Ctrl+Space or right Alt); a 한/EN indicator on the format bar"
        "rmpp-bt" = "Bluetooth: Settings > Bluetooth (search, pair, connect, forget), quick-settings toggle, on at boot, per-keyboard Type Folio mode"
        "rmpp-tailscale" = "Tailscale: Settings > Tailscale (on/off, QR-code login, status and devices, updates); SSH to the tablet from anywhere (~70 MB in /home)"
    }
}
function M([string]$k) { return $Text[$script:Lang][$k] }
function Say($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Die($m) { Write-Host "`nError: $m" -ForegroundColor Red; exit 1 }
foreach ($c in "ssh", "ssh-keygen") {
    if (-not (Get-Command $c -ErrorAction SilentlyContinue)) { Die "$c$(M 'missing')" }
}

# ---------------------------------------------------------------- checkbox menu
function Show-Menu([string[]]$Installed) {
    $sel = @($All | ForEach-Object { $true })          # everything starts selected
    $cur = 0
    $cursor = $true
    try { $cursor = [Console]::CursorVisible; [Console]::CursorVisible = $false } catch {}
    try {
        while ($true) {
            Clear-Host
            Write-Host "  $(M 'title')`n"
            for ($i = 0; $i -lt $All.Count; $i++) {
                $p = $All[$i]
                $box = if ($sel[$i]) { "[x]" } else { "[ ]" }
                $inst = if ($Installed -contains $p) { " $(M 'installed')" } else { "" }
                $line = " $(if ($i -eq $cur) { '>' } else { ' ' }) $box $p$inst"
                if ($i -eq $cur) { Write-Host $line -ForegroundColor Black -BackgroundColor Gray } else { Write-Host $line }
                Write-Host "       $(M $p)`n" -ForegroundColor DarkGray
            }
            Write-Host "  $(M 'keys')"
            $k = [Console]::ReadKey($true)
            switch ($k.Key) {
                "UpArrow" { if ($cur -gt 0) { $cur-- } }
                "DownArrow" { if ($cur -lt $All.Count - 1) { $cur++ } }
                "K" { if ($cur -gt 0) { $cur-- } }
                "J" { if ($cur -lt $All.Count - 1) { $cur++ } }
                "Spacebar" { $sel[$cur] = -not $sel[$cur] }
                "X" { $sel[$cur] = -not $sel[$cur] }
                "L" { $script:Lang = if ($script:Lang -eq "ko") { "en" } else { "ko" } }
                "Q" { Write-Host "`n$(M 'cancel')"; exit 0 }
                "Escape" { Write-Host "`n$(M 'cancel')"; exit 0 }
                "Enter" { return @(for ($i = 0; $i -lt $All.Count; $i++) { if ($sel[$i]) { $All[$i] } }) }
            }
        }
    } finally {
        try { [Console]::CursorVisible = $cursor } catch {}
    }
}

# ---------------------------------------------------------------- tablet
if (-not $TabletHost) {
    $TabletHost = Read-Host (M 'address')
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
    Say "$(M 'newkey') ($Key)"
    New-Item -ItemType Directory -Force (Split-Path $Key) | Out-Null
    # cmd /c passes the empty passphrase reliably on both PowerShell 5.1 and 7
    cmd /c "ssh-keygen -q -t ed25519 -N `"`" -C rmpp -f `"$Key`""
    if ($LASTEXITCODE -ne 0) { Die "ssh-keygen failed" }
}
if (-not (Remote "true" -Batch)) {
    Say "$TabletHost$(M 'password')"
    if (-not (SendFile "$Key.pub" "umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys")) { Die "$TabletHost$(M 'nologin')" }
    if (-not (Remote "true" -Batch)) { Die (M 'nokey') }
}
Say "$(M 'loggedin') $TabletHost"

# 2. Choose packages (menu in a console; -Packages / -Yes or redirected input: no menu).
$installedRaw = & ssh @SshOpts $Target '/home/root/.vellum/bin/vellum list 2>/dev/null | grep "\[installed\]" | cut -d" " -f1' 2>$null
$Installed = @($installedRaw | ForEach-Object { $_ -replace '-[0-9][^-]*-r[0-9]*$', '' })
if ($Packages.Count -gt 0) {
    $Selected = @($Packages | ForEach-Object { $_ -split "," } | Where-Object { $_ })
} elseif ($Yes -or [Console]::IsInputRedirected) {
    $Selected = $All
} else {
    $Selected = @(Show-Menu $Installed)
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("rmpp-" + [guid]::NewGuid())
New-Item -ItemType Directory $tmp | Out-Null
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 3. Vellum (skipped when already installed). The bootstrap is checked against the hash in Vellum's README.
if (Remote "[ -x /home/root/.vellum/bin/vellum ]") {
    Say (M 'vellum_ok')
} else {
    Say (M 'vellum')
    $boot = Join-Path $tmp "bootstrap.sh"
    Invoke-WebRequest -UseBasicParsing $BootstrapUrl -OutFile $boot
    $readme = (Invoke-WebRequest -UseBasicParsing $VellumReadme).Content
    $want = ([regex]'echo "([0-9a-f]{64})  bootstrap.sh"').Match($readme).Groups[1].Value
    $got = (Get-FileHash $boot -Algorithm SHA256).Hash.ToLower()
    if (-not $want -or $want -ne $got) { Die "$(M 'checksum') ($got, expected $want)" }
    if (-not (SendFile $boot "cat > /tmp/vellum-bootstrap.sh")) { Die (M 'vellum_fail') }
    if (-not (Remote "sh /tmp/vellum-bootstrap.sh; r=`$?; rm -f /tmp/vellum-bootstrap.sh; exit `$r")) { Die (M 'vellum_fail') }
}

# 4. This package repository and its signing key (downloaded here, so the tablet needs no TLS certificates).
Say (M 'repo')
$pubKey = Join-Path $tmp "lorancecall-rmpp.rsa.pub"
Invoke-WebRequest -UseBasicParsing "$Repo/lorancecall-rmpp.rsa.pub" -OutFile $pubKey
if (-not (SendFile $pubKey "cat > /home/root/.vellum/etc/apk/keys/lorancecall-rmpp.rsa.pub")) { Die "could not copy the repository key" }
Remote "grep -qxF '$Repo' /home/root/.vellum/etc/apk/repositories || echo '$Repo' >> /home/root/.vellum/etc/apk/repositories" | Out-Null

# 5. Packages. The tablet's screen restarts once or twice while they install.
if ($Selected.Count -gt 0) {
    $list = $Selected -join " "
    Say "$(M 'installing') $list"
    if (-not (Remote "/home/root/.vellum/bin/vellum update && /home/root/.vellum/bin/vellum add $list")) { Die (M 'install_fail') }
} else {
    Say (M 'nothing')
}

# 6. After a reMarkable OS update the files in the root file system are gone: restore them.
if (($Installed.Count + $Selected.Count) -gt 0 -and (Remote "[ ! -x /usr/lib/rmpp-preload/launch ]")) {
    Say (M 'reenable')
    if (-not (Remote "/home/root/.vellum/bin/vellum reenable")) { Die (M 'reenable_fail') }
}

Remove-Item -Recurse -Force $tmp
Say (M 'done')
Write-Host (M 'again')
Write-Host "$(M 'remove') ssh -i `"$Key`" $Target /home/root/.vellum/bin/vellum del <package>"
