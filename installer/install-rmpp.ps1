# Install rmpp mods on a reMarkable Paper Pro. The mods come from a catalog: mods.txt lists GitHub repositories
# and each repository describes itself in rmpp-mod.conf (see MODS.md), so new mods need no installer change.
# A checkbox menu lets you pick them; the menu and messages are in Korean or English (L switches).
# Runs on Windows 10/11 with the built-in OpenSSH client, in Windows PowerShell 5.1 or PowerShell 7.
#
#   irm https://lorancecall.github.io/rmpp-packages/install-rmpp.ps1 -OutFile install-rmpp.ps1
#   powershell -ExecutionPolicy Bypass -File install-rmpp.ps1 [-TabletHost 10.11.99.1] [-Lang ko|en]
#                                                             [-Packages rmpp-bt,rmpp-tailscale] [-Yes]
#   (or the same with pwsh, PowerShell 7)
#
#   -Packages  install these mods without the menu
#   -Yes       no menu: install the default selection (or the -Packages list)
#   -Catalog   folder with rmpp-mod.conf files (*.conf, in name order) instead of the online catalog
#
# Before you start, turn on developer mode on the tablet. The root password is shown in
# Settings > General > Help > About > Copyrights and licenses.
# (Saved as UTF-8 with BOM so that Windows PowerShell 5.1 reads the Korean text correctly.)
param([string]$TabletHost = "", [string]$Lang = "", [string[]]$Packages = @(), [switch]$Yes, [string]$Catalog = "")

$ErrorActionPreference = "Stop"
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Repo = "https://lorancecall.github.io/rmpp-packages"
$VellumReadme = "https://raw.githubusercontent.com/vellum-dev/vellum-cli/main/README.md"
$BootstrapUrl = "https://github.com/vellum-dev/vellum-cli/releases/latest/download/bootstrap.sh"
$Key = Join-Path $HOME ".ssh\id_ed25519_rmpp"
$Utf8 = New-Object System.Text.UTF8Encoding $false
if (-not $Lang) { $Lang = if ((Get-Culture).Name -like "ko*") { "ko" } else { "en" } }

# ---------------------------------------------------------------- installer messages (Korean / English)
$Text = @{
    ko = @{
        missing = "가 설치되어 있지 않습니다 (설정 > 앱 > 선택적 기능 > OpenSSH 클라이언트)"
        catalog = "mod 목록을 받습니다"; catalog_fail = "mod 목록을 받지 못했습니다"; conf_fail = "설명을 받지 못해 건너뜁니다:"
        address = "태블릿 주소 [USB는 10.11.99.1, 또는 Wi-Fi IP]"
        newkey = "태블릿용 SSH 키를 만듭니다"
        password = "에 로그인합니다. 태블릿의 root 비밀번호를 입력하세요."
        nologin = "에 로그인할 수 없습니다"; nokey = "키가 받아들여지지 않았습니다"; loggedin = "로그인했습니다:"
        vellum_ok = "Vellum이 이미 설치되어 있습니다"; vellum = "Vellum을 설치합니다"
        checksum = "Vellum bootstrap 체크섬이 맞지 않습니다"; vellum_fail = "Vellum 설치에 실패했습니다"
        repo = "rmpp 패키지 저장소를 추가합니다"
        installing = "설치합니다 (태블릿 화면이 한두 번 다시 시작됩니다):"; install_fail = "설치에 실패했습니다"
        release = "GitHub 릴리스에서 받아 설치합니다:"; release_fail = "릴리스 파일을 받지 못했습니다"
        unknown = "목록에 없는 mod입니다:"; nothing = "선택한 항목이 없습니다. 저장소만 추가했습니다."
        reenable = "OS 업데이트 뒤의 시스템 파일을 복구합니다 (vellum reenable)"; reenable_fail = "vellum reenable에 실패했습니다"
        cancel = "취소했습니다. 아무것도 설치하지 않았습니다."; done = "완료."
        again = "reMarkable OS를 업데이트한 뒤에는 이 스크립트를 다시 실행하세요."; remove = "Vellum 패키지 제거:"
        title = "rmpp 설치"; lang = "한국어"; col_name = "이름"; col_desc = "설명"
        keys = "↑↓ 이동   Space 선택   L English   Enter 설치   Q 취소"; installed = "설치됨"; default = "기본 선택"
    }
    en = @{
        missing = " is not installed (Settings > Apps > Optional features > OpenSSH Client)"
        catalog = "Getting the list of mods"; catalog_fail = "could not get the list of mods"; conf_fail = "no description, skipped:"
        address = "Tablet address [10.11.99.1 over USB, or its Wi-Fi IP]"
        newkey = "Creating an SSH key for the tablet"
        password = ": logging in. Type the tablet's root password when asked."
        nologin = ": could not log in"; nokey = "the key was not accepted"; loggedin = "Logged in to"
        vellum_ok = "Vellum is already installed"; vellum = "Installing Vellum"
        checksum = "Vellum bootstrap checksum mismatch"; vellum_fail = "Vellum installation failed"
        repo = "Adding the rmpp package repository"
        installing = "Installing (the tablet's screen restarts once or twice):"; install_fail = "installation failed"
        release = "Installing from the GitHub release:"; release_fail = "could not download the release files"
        unknown = "not in the list of mods:"; nothing = "Nothing selected; only the repository was added."
        reenable = "Restoring system files after an OS update (vellum reenable)"; reenable_fail = "vellum reenable failed"
        cancel = "Cancelled. Nothing was installed."; done = "Done."
        again = "After a reMarkable OS update, run this script again."; remove = "Remove a Vellum package:"
        title = "rmpp setup"; lang = "English"; col_name = "Name"; col_desc = "What it does"
        keys = "↑↓ move   Space toggle   L 한국어   Enter install   Q quit"; installed = "installed"; default = "default"
    }
}
function M([string]$k) { return $Text[$script:Lang][$k] }
function Say($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Die($m) { Write-Host "`nError: $m" -ForegroundColor Red; exit 1 }
foreach ($c in "ssh", "ssh-keygen") {
    if (-not (Get-Command $c -ErrorAction SilentlyContinue)) { Die "$c$(M 'missing')" }
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("rmpp-" + [guid]::NewGuid())
New-Item -ItemType Directory $tmp | Out-Null

# ---------------------------------------------------------------- catalog
function Read-Conf([string]$path, [string]$repo) {
    $c = @{ repo = $repo }
    foreach ($line in [System.IO.File]::ReadAllLines($path, $Utf8)) {
        if ($line -match '^\s*#' -or $line -notmatch '=') { continue }
        $k, $v = $line.TrimEnd("`r") -split '=', 2
        if (-not $c.ContainsKey($k)) { $c[$k] = $v }
    }
    return $c
}
$Mods = @()
if ($Catalog) {
    foreach ($f in Get-ChildItem (Join-Path $Catalog "*.conf") | Sort-Object Name) { $Mods += Read-Conf $f.FullName ("local/" + $f.BaseName) }
} else {
    Say (M 'catalog')
    $list = Join-Path $tmp "mods.txt"
    try { Invoke-WebRequest -UseBasicParsing "$Repo/mods.txt" -OutFile $list } catch { Die (M 'catalog_fail') }
    foreach ($line in [System.IO.File]::ReadAllLines($list, $Utf8)) {
        $r = ($line -replace '#.*', '').Trim()
        if (-not $r) { continue }
        $cf = Join-Path $tmp "x.conf"
        try {
            Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/$r/HEAD/rmpp-mod.conf" -OutFile $cf
            $Mods += Read-Conf $cf $r
        } catch { Write-Host "  $(M 'conf_fail') $r" -ForegroundColor Yellow }
    }
}
$All = @($Mods | ForEach-Object { $_.id })
$Defaults = @($Mods | Where-Object { $_.default -eq "1" } | ForEach-Object { $_.id })

# ---------------------------------------------------------------- checkbox menu
function Width([string]$s) {   # display columns: Hangul syllables and other wide characters take 2
    $w = 0
    foreach ($ch in $s.ToCharArray()) { $w += if ([int]$ch -ge 0x1100 -and ([int]$ch -le 0x115F -or ([int]$ch -ge 0xAC00 -and [int]$ch -le 0xD7A3) -or ([int]$ch -ge 0x3130 -and [int]$ch -le 0x318F))) { 2 } else { 1 } }
    return $w
}
function Pad([string]$s, [int]$w) { return $s + (" " * [Math]::Max(0, $w - (Width $s))) }

function Show-Menu([string[]]$Installed) {
    $sel = @($All | ForEach-Object { ($Defaults -contains $_) -or ($Installed -contains $_) })
    $cur = 0
    $rule = "  " + ("─" * 70)
    $cursor = $true
    try { $cursor = [Console]::CursorVisible; [Console]::CursorVisible = $false } catch {}
    try {
        while ($true) {
            Clear-Host
            Write-Host ""
            Write-Host "  $(M 'title')" -NoNewline -ForegroundColor White; Write-Host "   [$(M 'lang')]"
            Write-Host $rule
            Write-Host ("        " + (Pad (M 'col_name') 17) + " " + (M 'col_desc')) -ForegroundColor DarkGray
            for ($i = 0; $i -lt $All.Count; $i++) {
                $m = $Mods[$i]
                $box = if ($sel[$i]) { "[x]" } else { "[ ]" }
                $st = if ($Installed -contains $m.id) { "  ($(M 'installed'))" } else { "" }
                $row = (Pad $m.id 17) + " " + (Pad $m["short_$script:Lang"] 38) + $st
                if ($i -eq $cur) { Write-Host "  > $box $row" -ForegroundColor Black -BackgroundColor Gray }
                else { Write-Host "    $box $row" }
            }
            $m = $Mods[$cur]
            $tags = @()
            if ($Defaults -contains $m.id) { $tags += (M 'default') }
            if ($Installed -contains $m.id) { $tags += (M 'installed') }
            Write-Host $rule
            Write-Host "  $($m.id)" -NoNewline -ForegroundColor White
            if ($tags) { Write-Host "   ($($tags -join ' · '))" } else { Write-Host "" }
            foreach ($line in ($m["detail_$script:Lang"] -split '\|')) { Write-Host "    $line" }
            Write-Host $rule
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

# Run a command on the tablet. No double quotes inside $Cmd: Windows PowerShell 5.1 drops them when it passes
# arguments to native programs.
function Remote([string]$Cmd, [switch]$Batch, [switch]$Quiet) {
    $opts = $SshOpts
    if ($Batch) { $opts = $opts + @("-o", "BatchMode=yes", "-o", "ConnectTimeout=8") }
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    if ($Quiet) { & ssh @opts $Target $Cmd 2>$null | Out-Null } else { & ssh @opts $Target $Cmd | Out-Host }
    $ok = ($LASTEXITCODE -eq 0)
    $ErrorActionPreference = $prev
    return $ok
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
if (-not (Remote "true" -Batch -Quiet)) {
    Say "$TabletHost$(M 'password')"
    if (-not (SendFile "$Key.pub" "umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys")) { Die "$TabletHost$(M 'nologin')" }
    if (-not (Remote "true" -Batch -Quiet)) { Die (M 'nokey') }
}
Say "$(M 'loggedin') $TabletHost"

# 2. What is installed, then choose (menu in a console; -Packages / -Yes or redirected input: no menu).
$prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
$vraw = & ssh @SshOpts $Target "/home/root/.vellum/bin/vellum list 2>/dev/null | grep -F '[installed]' | cut -d' ' -f1" 2>$null
$ErrorActionPreference = $prev
$VList = @($vraw | Where-Object { $_ } | ForEach-Object { $_ -replace '-[0-9][^-]*-r[0-9]*$', '' })
$Installed = @()
foreach ($m in $Mods) {
    if ($m.type -eq "vellum") { if ($VList -contains $m.package) { $Installed += $m.id } }
    elseif ($m.check -and (Remote $m.check -Quiet)) { $Installed += $m.id }
}
if ($Packages.Count -gt 0) {
    $Chosen = @($Packages | ForEach-Object { $_ -split "," } | Where-Object { $_ })
} elseif ($Yes -or [Console]::IsInputRedirected) {
    $Chosen = $Defaults
} else {
    $Chosen = @(Show-Menu $Installed)
}
$Vellum = @(); $Releases = @()
foreach ($id in $Chosen) {
    $m = $Mods | Where-Object { $_.id -eq $id } | Select-Object -First 1
    if (-not $m) { Die "$(M 'unknown') $id" }
    if ($m.type -eq "vellum") { $Vellum += $m.package } else { $Releases += $m }
    if ($m.needs) { foreach ($d in ($m.needs -split ' ')) { if ($d -and $Vellum -notcontains $d) { $Vellum += $d } } }
}

# 3. Vellum (skipped when already installed). The bootstrap is checked against the hash in Vellum's README.
if (Remote "[ -x /home/root/.vellum/bin/vellum ]" -Quiet) {
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

# 5. Vellum packages, then release mods. The tablet's screen restarts once or twice.
if ($Vellum.Count -gt 0) {
    $list = $Vellum -join " "
    Say "$(M 'installing') $list"
    if (-not (Remote "/home/root/.vellum/bin/vellum update && /home/root/.vellum/bin/vellum add $list")) { Die (M 'install_fail') }
}
foreach ($m in $Releases) {
    Say "$(M 'release') $($m.id) ($($m.repo))"
    $dir = "/home/root/.cache/rmpp-mods/$($m.id)"
    $local = Join-Path $tmp $m.id
    New-Item -ItemType Directory -Force $local | Out-Null
    foreach ($a in ($m.assets -split ' ' | Where-Object { $_ })) {
        try { Invoke-WebRequest -UseBasicParsing "https://github.com/$($m.repo)/releases/latest/download/$a" -OutFile (Join-Path $local $a) }
        catch { Die "$(M 'release_fail') ($a)" }
    }
    Remote "rm -rf $dir && mkdir -p $dir" | Out-Null
    foreach ($a in ($m.assets -split ' ' | Where-Object { $_ })) {
        if (-not (SendFile (Join-Path $local $a) "cat > $dir/$a")) { Die "$(M 'install_fail') ($a)" }
    }
    if (-not (Remote "cd $dir && sh rmpp-install.sh; r=`$?; cd / && rm -rf $dir; exit `$r")) { Die "$(M 'install_fail') ($($m.id))" }
}
if ($Vellum.Count -eq 0 -and $Releases.Count -eq 0) { Say (M 'nothing') }

# 6. After a reMarkable OS update the files in the root file system are gone: restore them.
if (($VList.Count + $Vellum.Count) -gt 0 -and (Remote "[ ! -x /usr/lib/rmpp-preload/launch ] && [ -x /home/root/.vellum/bin/vellum ]" -Quiet)) {
    Say (M 'reenable')
    if (-not (Remote "/home/root/.vellum/bin/vellum reenable")) { Die (M 'reenable_fail') }
}

Remove-Item -Recurse -Force $tmp
Say (M 'done')
Write-Host (M 'again')
Write-Host "$(M 'remove') ssh -i `"$Key`" $Target /home/root/.vellum/bin/vellum del <package>"
