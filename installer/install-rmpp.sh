#!/bin/sh
# Install Vellum and the rmpp packages on a reMarkable Paper Pro. A checkbox menu lets you pick the packages
# (Korean keyboard, Bluetooth, Tailscale); the menu and messages are in Korean or English (L switches).
# Runs on your computer (Linux or macOS). Needs: ssh, ssh-keygen, curl.
#
#   curl -fsSL https://lorancecall.github.io/rmpp-packages/install-rmpp.sh -o install-rmpp.sh
#   sh install-rmpp.sh [tablet-address] [--lang ko|en] [--packages rmpp-korean,rmpp-bt] [--yes]
#
#   --packages  install these without the menu (comma separated)
#   --yes       no menu: install every package (or the --packages list)
#
# Before you start, turn on developer mode on the tablet. The root password is shown in
# Settings > General > Help > About > Copyrights and licenses.
set -e

REPO=https://lorancecall.github.io/rmpp-packages
VELLUM_README=https://raw.githubusercontent.com/vellum-dev/vellum-cli/main/README.md
BOOTSTRAP_URL=https://github.com/vellum-dev/vellum-cli/releases/latest/download/bootstrap.sh
ALL="rmpp-korean rmpp-bt rmpp-tailscale"
KEY="$HOME/.ssh/id_ed25519_rmpp"

HOST="" LANG_UI="" PICK="" YES=""
while [ $# -gt 0 ]; do
	case "$1" in
		--lang) LANG_UI=$2; shift ;;
		--lang=*) LANG_UI=${1#*=} ;;
		--packages) PICK=$(echo "$2" | tr ',' ' '); shift ;;
		--packages=*) PICK=$(echo "${1#*=}" | tr ',' ' ') ;;
		--yes|-y) YES=1 ;;
		-*) echo "unknown option $1" >&2; exit 2 ;;
		*) HOST=$1 ;;
	esac
	shift
done
if [ -z "$LANG_UI" ]; then
	case "${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" in ko*) LANG_UI=ko ;; *) LANG_UI=en ;; esac
fi

# ---------------------------------------------------------------- messages (Korean / English)
m() {   # m KEY -> text in the current language
	if [ "$LANG_UI" = ko ]; then
		case "$1" in
			missing) echo "가 설치되어 있지 않습니다" ;;
			address) echo "태블릿 주소 [USB는 10.11.99.1, 또는 Wi-Fi IP]: " ;;
			newkey) echo "태블릿용 SSH 키를 만듭니다" ;;
			password) echo "에 로그인합니다. 태블릿의 root 비밀번호를 입력하세요." ;;
			nologin) echo "에 로그인할 수 없습니다" ;;
			nokey) echo "키가 받아들여지지 않았습니다" ;;
			loggedin) echo "로그인했습니다:" ;;
			vellum_ok) echo "Vellum이 이미 설치되어 있습니다" ;;
			vellum) echo "Vellum을 설치합니다" ;;
			checksum) echo "Vellum bootstrap 체크섬이 맞지 않습니다" ;;
			vellum_fail) echo "Vellum 설치에 실패했습니다" ;;
			repo) echo "rmpp 패키지 저장소를 추가합니다" ;;
			installing) echo "설치합니다 (태블릿 화면이 한두 번 다시 시작됩니다):" ;;
			install_fail) echo "패키지 설치에 실패했습니다" ;;
			nothing) echo "선택한 패키지가 없습니다. 저장소만 추가했습니다." ;;
			reenable) echo "OS 업데이트 뒤의 시스템 파일을 복구합니다 (vellum reenable)" ;;
			reenable_fail) echo "vellum reenable에 실패했습니다" ;;
			cancel) echo "취소했습니다." ;;
			done) echo "완료. 태블릿에서: 설정 > 언어 및 키보드 > 한국어, 설정 > 블루투스, 설정 > Tailscale." ;;
			again) echo "reMarkable OS를 업데이트한 뒤에는 이 스크립트를 다시 실행하세요 (vellum reenable을 실행합니다)." ;;
			remove) echo "제거:" ;;
			title) echo "설치할 기능을 고르세요" ;;
			keys) echo "↑↓ 이동   Space 선택   L English   Enter 설치   Q 취소" ;;
			installed) echo "(설치됨)" ;;
			rmpp-korean) echo "한글 입력: 화면 키보드 한국어 자판과 글꼴, 블루투스·USB·Type Folio 키보드로 한글 입력 (Ctrl+Space 또는 오른쪽 Alt로 전환), 서식 막대의 한/EN 표시" ;;
			rmpp-bt) echo "블루투스: 설정 > 블루투스 (검색, 페어링, 연결, 삭제), 빠른 설정 토글, 부팅할 때 자동으로 켜짐, 키보드별 Type Folio 모드" ;;
			rmpp-tailscale) echo "Tailscale: 설정 > Tailscale (켜기/끄기, QR 코드 로그인, 상태와 기기 목록, 업데이트), 어디서나 Tailscale로 SSH 접속 (/home에 약 70 MB)" ;;
		esac
	else
		case "$1" in
			missing) echo "is not installed" ;;
			address) echo "Tablet address [10.11.99.1 over USB, or its Wi-Fi IP]: " ;;
			newkey) echo "Creating an SSH key for the tablet" ;;
			password) echo ": logging in. Type the tablet's root password when asked." ;;
			nologin) echo ": could not log in" ;;
			nokey) echo "the key was not accepted" ;;
			loggedin) echo "Logged in to" ;;
			vellum_ok) echo "Vellum is already installed" ;;
			vellum) echo "Installing Vellum" ;;
			checksum) echo "Vellum bootstrap checksum mismatch" ;;
			vellum_fail) echo "Vellum installation failed" ;;
			repo) echo "Adding the rmpp package repository" ;;
			installing) echo "Installing (the tablet's screen restarts once or twice):" ;;
			install_fail) echo "package installation failed" ;;
			nothing) echo "No package selected; only the repository was added." ;;
			reenable) echo "Restoring system files after an OS update (vellum reenable)" ;;
			reenable_fail) echo "vellum reenable failed" ;;
			cancel) echo "Cancelled." ;;
			done) echo "Done. On the tablet: Settings > Language & keyboard > Korean; Settings > Bluetooth; Settings > Tailscale." ;;
			again) echo "After a reMarkable OS update, run this script again (it runs 'vellum reenable')." ;;
			remove) echo "Remove with:" ;;
			title) echo "Choose what to install" ;;
			keys) echo "↑↓ move   Space toggle   L 한국어   Enter install   Q quit" ;;
			installed) echo "(installed)" ;;
			rmpp-korean) echo "Korean input: on-screen Hangul keyboard and fonts; type Korean on Bluetooth/USB/Type Folio keyboards (Ctrl+Space or right Alt); a 한/EN indicator on the format bar" ;;
			rmpp-bt) echo "Bluetooth: Settings > Bluetooth (search, pair, connect, forget), quick-settings toggle, on at boot, per-keyboard Type Folio mode" ;;
			rmpp-tailscale) echo "Tailscale: Settings > Tailscale (on/off, QR-code login, status and devices, updates); SSH to the tablet from anywhere (~70 MB in /home)" ;;
		esac
	fi
}
say() { printf '\n==> %s\n' "$*"; }
die() { printf '\nError: %s\n' "$*" >&2; exit 1; }
for c in ssh ssh-keygen curl; do command -v "$c" >/dev/null 2>&1 || die "$c $(m missing)"; done

# ---------------------------------------------------------------- checkbox menu
# Plain POSIX sh: the terminal is put in raw mode and keys are read byte by byte with dd.
menu() {   # $1 = installed packages; sets SELECTED
	n=$(echo $ALL | wc -w | tr -d ' ')
	cur=1
	sel=""
	for p in $ALL; do sel="$sel 1"; done                # everything starts selected
	old=$(stty -g)
	trap 'stty "$old"; printf "\033[?25h"' EXIT INT TERM
	stty -icanon -echo min 1 time 0
	printf '\033[?25l'
	while :; do
		printf '\033[H\033[2J  %s\n\n' "$(m title)"
		i=1
		for p in $ALL; do
			s=$(echo $sel | cut -d' ' -f$i)
			box="[ ]"; [ "$s" = 1 ] && box="[x]"
			mark=" "; [ $i = $cur ] && mark=">"
			inst=""; case " $1 " in *" $p "*) inst=" $(m installed)" ;; esac
			if [ $i = $cur ]; then printf '\033[7m %s %s %s%s \033[0m\n' "$mark" "$box" "$p" "$inst"
			else printf ' %s %s %s%s\n' "$mark" "$box" "$p" "$inst"; fi
			printf '       %s\n\n' "$(m "$p")"
			i=$((i + 1))
		done
		printf '  %s\n' "$(m keys)"
		k=$(dd bs=1 count=1 2>/dev/null)
		if [ "$k" = "$(printf '\033')" ]; then
			k2=$(dd bs=1 count=1 2>/dev/null); k3=$(dd bs=1 count=1 2>/dev/null)
			case "$k2$k3" in "[A"|"OA") [ $cur -gt 1 ] && cur=$((cur - 1)) ;; "[B"|"OB") [ $cur -lt $n ] && cur=$((cur + 1)) ;; esac
			continue
		fi
		case "$k" in
			" "|x|X)
				new=""; i=1
				for s in $sel; do
					if [ $i = $cur ]; then s=$((1 - s)); fi
					new="$new $s"; i=$((i + 1))
				done
				sel=$new ;;
			k|K) [ $cur -gt 1 ] && cur=$((cur - 1)) ;;
			j|J) [ $cur -lt $n ] && cur=$((cur + 1)) ;;
			l|L) if [ "$LANG_UI" = ko ]; then LANG_UI=en; else LANG_UI=ko; fi ;;
			q|Q) stty "$old"; printf '\033[?25h\n'; trap - EXIT INT TERM; echo "$(m cancel)"; exit 0 ;;
			""|"$(printf '\r')") break ;;
		esac
	done
	stty "$old"; printf '\033[?25h\n'; trap - EXIT INT TERM
	SELECTED=""; i=1
	for p in $ALL; do
		[ "$(echo $sel | cut -d' ' -f$i)" = 1 ] && SELECTED="$SELECTED $p"
		i=$((i + 1))
	done
	SELECTED=${SELECTED# }
}

# ---------------------------------------------------------------- tablet
if [ -z "$HOST" ]; then
	printf '%s' "$(m address)"
	read -r HOST
	HOST=${HOST:-10.11.99.1}
fi
TARGET="root@$HOST"
SSH="ssh -i $KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"

# 1. SSH key: the password is asked once, then the key is used.
if [ ! -f "$KEY" ]; then
	say "$(m newkey) ($KEY)"
	mkdir -p "$HOME/.ssh"
	ssh-keygen -q -t ed25519 -N "" -C "rmpp" -f "$KEY"
fi
if ! $SSH -o BatchMode=yes -o ConnectTimeout=8 "$TARGET" true 2>/dev/null; then
	say "$HOST$(m password)"
	$SSH -o ConnectTimeout=8 "$TARGET" \
		'umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys' < "$KEY.pub" ||
		die "$HOST$(m nologin)"
	$SSH -o BatchMode=yes "$TARGET" true || die "$(m nokey)"
fi
say "$(m loggedin) $HOST"

# 2. Choose packages (menu on a terminal; --packages / --yes or no terminal: no menu).
INSTALLED=$($SSH "$TARGET" '/home/root/.vellum/bin/vellum list 2>/dev/null | grep "\[installed\]" | cut -d" " -f1' 2>/dev/null |
	sed 's/-[0-9][^-]*-r[0-9]*$//' | tr '\n' ' ' || true)
if [ -n "$PICK" ]; then
	PACKAGES=$PICK
elif [ -n "$YES" ] || [ ! -t 0 ] || [ ! -t 1 ]; then
	PACKAGES=$ALL
else
	menu "$INSTALLED"
	PACKAGES=$SELECTED
fi

# 3. Vellum (skipped when already installed). The bootstrap is checked against the hash in Vellum's README.
if $SSH "$TARGET" '[ -x /home/root/.vellum/bin/vellum ]'; then
	say "$(m vellum_ok)"
else
	say "$(m vellum)"
	tmp=$(mktemp -d)
	curl -fsSL "$BOOTSTRAP_URL" -o "$tmp/bootstrap.sh"
	want=$(curl -fsSL "$VELLUM_README" | sed -n 's/.*echo "\([0-9a-f]\{64\}\)  bootstrap.sh".*/\1/p' | head -n 1)
	if command -v sha256sum >/dev/null 2>&1; then got=$(sha256sum "$tmp/bootstrap.sh" | cut -d' ' -f1)
	else got=$(shasum -a 256 "$tmp/bootstrap.sh" | cut -d' ' -f1); fi
	[ -n "$want" ] && [ "$want" = "$got" ] || die "$(m checksum) ($got, expected $want)"
	$SSH "$TARGET" 'cat > /tmp/vellum-bootstrap.sh && sh /tmp/vellum-bootstrap.sh; r=$?; rm -f /tmp/vellum-bootstrap.sh; exit $r' \
		< "$tmp/bootstrap.sh" || die "$(m vellum_fail)"
	rm -rf "$tmp"
fi

# 4. This package repository and its signing key (downloaded here, so the tablet needs no TLS certificates).
say "$(m repo)"
curl -fsSL "$REPO/lorancecall-rmpp.rsa.pub" |
	$SSH "$TARGET" 'cat > /home/root/.vellum/etc/apk/keys/lorancecall-rmpp.rsa.pub'
$SSH "$TARGET" "grep -qxF '$REPO' /home/root/.vellum/etc/apk/repositories || echo '$REPO' >> /home/root/.vellum/etc/apk/repositories"

# 5. Packages. The tablet's screen restarts once or twice while they install.
if [ -n "$PACKAGES" ]; then
	say "$(m installing) $PACKAGES"
	$SSH "$TARGET" "/home/root/.vellum/bin/vellum update && /home/root/.vellum/bin/vellum add $PACKAGES" ||
		die "$(m install_fail)"
else
	say "$(m nothing)"
fi

# 6. After a reMarkable OS update the files in the root file system are gone: restore them.
if [ -n "$INSTALLED$PACKAGES" ] && $SSH "$TARGET" '[ ! -x /usr/lib/rmpp-preload/launch ]'; then
	say "$(m reenable)"
	$SSH "$TARGET" '/home/root/.vellum/bin/vellum reenable' || die "$(m reenable_fail)"
fi

say "$(m done)"
echo "$(m again)"
echo "$(m remove) ssh -i $KEY $TARGET /home/root/.vellum/bin/vellum del <package>"
