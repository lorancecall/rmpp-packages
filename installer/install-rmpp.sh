#!/bin/sh
# Install rmpp mods on a reMarkable Paper Pro. The mods come from a catalog: mods.txt lists GitHub repositories
# and each repository describes itself in rmpp-mod.conf (see MODS.md), so new mods need no installer change.
# A checkbox menu lets you pick them; the menu and messages are in Korean or English (L switches).
# Runs on your computer (Linux or macOS). Needs: ssh, ssh-keygen, curl.
#
#   curl -fsSL https://lorancecall.github.io/rmpp-packages/install-rmpp.sh -o install-rmpp.sh
#   sh install-rmpp.sh [tablet-address] [--lang ko|en] [--packages rmpp-bt,rmpp-tailscale] [--yes]
#
#   --packages ID,..  install these without the menu
#   --yes             no menu: install the default selection (or the --packages list)
#   --catalog DIR     use the rmpp-mod.conf files in DIR (*.conf, in name order) instead of the online catalog
#
# Before you start, turn on developer mode on the tablet. The root password is shown in
# Settings > General > Help > About > Copyrights and licenses.
set -e

REPO=https://lorancecall.github.io/rmpp-packages
VELLUM_README=https://raw.githubusercontent.com/vellum-dev/vellum-cli/main/README.md
BOOTSTRAP_URL=https://github.com/vellum-dev/vellum-cli/releases/latest/download/bootstrap.sh
KEY="$HOME/.ssh/id_ed25519_rmpp"

HOST="" LANG_UI="" PICK="" YES="" CATALOG_DIR=""
while [ $# -gt 0 ]; do
	case "$1" in
		--lang) LANG_UI=$2; shift ;;
		--lang=*) LANG_UI=${1#*=} ;;
		--packages) PICK=$(echo "$2" | tr ',' ' '); shift ;;
		--packages=*) PICK=$(echo "${1#*=}" | tr ',' ' ') ;;
		--catalog) CATALOG_DIR=$2; shift ;;
		--yes|-y) YES=1 ;;
		-*) echo "unknown option $1" >&2; exit 2 ;;
		*) HOST=$1 ;;
	esac
	shift
done
if [ -z "$LANG_UI" ]; then
	case "${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" in ko*) LANG_UI=ko ;; *) LANG_UI=en ;; esac
fi

# ---------------------------------------------------------------- installer messages (Korean / English)
m() {
	if [ "$LANG_UI" = ko ]; then
		case "$1" in
			missing) echo "가 설치되어 있지 않습니다" ;;
			catalog) echo "mod 목록을 받습니다" ;;
			catalog_fail) echo "mod 목록을 받지 못했습니다" ;;
			conf_fail) echo "설명을 받지 못해 건너뜁니다:" ;;
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
			install_fail) echo "설치에 실패했습니다" ;;
			release) echo "GitHub 릴리스에서 받아 설치합니다:" ;;
			release_fail) echo "릴리스 파일을 받지 못했습니다" ;;
			unknown) echo "목록에 없는 mod입니다:" ;;
			nothing) echo "선택한 항목이 없습니다. 저장소만 추가했습니다." ;;
			reenable) echo "OS 업데이트 뒤의 시스템 파일을 복구합니다 (vellum reenable)" ;;
			reenable_fail) echo "vellum reenable에 실패했습니다" ;;
			cancel) echo "취소했습니다. 아무것도 설치하지 않았습니다." ;;
			done) echo "완료." ;;
			again) echo "reMarkable OS를 업데이트한 뒤에는 이 스크립트를 다시 실행하세요." ;;
			remove) echo "Vellum 패키지 제거:" ;;
			title) echo "rmpp 설치" ;;
			lang) echo "한국어" ;;
			col_name) echo "이름" ;;
			col_desc) echo "설명" ;;
			keys) echo "↑↓ 이동   Space 선택   L English   Enter 설치   Q 취소" ;;
			installed) echo "설치됨" ;;
			default) echo "기본 선택" ;;
		esac
	else
		case "$1" in
			missing) echo " is not installed" ;;
			catalog) echo "Getting the list of mods" ;;
			catalog_fail) echo "could not get the list of mods" ;;
			conf_fail) echo "no description, skipped:" ;;
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
			install_fail) echo "installation failed" ;;
			release) echo "Installing from the GitHub release:" ;;
			release_fail) echo "could not download the release files" ;;
			unknown) echo "not in the list of mods:" ;;
			nothing) echo "Nothing selected; only the repository was added." ;;
			reenable) echo "Restoring system files after an OS update (vellum reenable)" ;;
			reenable_fail) echo "vellum reenable failed" ;;
			cancel) echo "Cancelled. Nothing was installed." ;;
			done) echo "Done." ;;
			again) echo "After a reMarkable OS update, run this script again." ;;
			remove) echo "Remove a Vellum package:" ;;
			title) echo "rmpp setup" ;;
			lang) echo "English" ;;
			col_name) echo "Name" ;;
			col_desc) echo "What it does" ;;
			keys) echo "↑↓ move   Space toggle   L 한국어   Enter install   Q quit" ;;
			installed) echo "installed" ;;
			default) echo "default" ;;
		esac
	fi
}
say() { printf '\n==> %s\n' "$*"; }
die() { printf '\nError: %s\n' "$*" >&2; exit 1; }
for c in ssh ssh-keygen curl; do command -v "$c" >/dev/null 2>&1 || die "$c$(m missing)"; done

# ---------------------------------------------------------------- catalog
# $CAT/<n>.conf (rmpp-mod.conf of mod n) and $CAT/<n>.repo; ALL = ids in catalog order.
CAT=$(mktemp -d)
trap 'rm -rf "$CAT"' EXIT
n=0
if [ -n "$CATALOG_DIR" ]; then
	for f in "$CATALOG_DIR"/*.conf; do
		n=$((n + 1)); tr -d '\r' < "$f" > "$CAT/$n.conf"; echo "local/$(basename "$f" .conf)" > "$CAT/$n.repo"
	done
else
	say "$(m catalog)"
	curl -fsSL "$REPO/mods.txt" -o "$CAT/mods.txt" || die "$(m catalog_fail)"
	for r in $(tr -d '\r' < "$CAT/mods.txt" | sed 's/#.*//'); do
		if curl -fsSL "https://raw.githubusercontent.com/$r/HEAD/rmpp-mod.conf" -o "$CAT/x.conf"; then
			n=$((n + 1)); tr -d '\r' < "$CAT/x.conf" > "$CAT/$n.conf"; echo "$r" > "$CAT/$n.repo"
		else
			echo "  $(m conf_fail) $r" >&2
		fi
	done
fi
NMODS=$n
cf() { sed -n "s/^$2=//p" "$CAT/$1.conf" | head -n 1; }      # cf <n> <key>
idx() { i=1; while [ $i -le $NMODS ]; do [ "$(cf $i id)" = "$1" ] && { echo $i; return; }; i=$((i + 1)); done; }
ALL=""; DEFAULTS=""
i=1
while [ $i -le $NMODS ]; do
	ALL="$ALL $(cf $i id)"
	[ "$(cf $i default)" = 1 ] && DEFAULTS="$DEFAULTS $(cf $i id)"
	i=$((i + 1))
done

# ---------------------------------------------------------------- checkbox menu
# Plain POSIX sh: the terminal is put in raw mode and keys are read byte by byte with dd.
# Layout: one row per mod (checkbox, name, short description, installed), then the full description of the
# mod under the cursor (pre-wrapped lines from rmpp-mod.conf).
pad() {   # pad TEXT WIDTH: left-justify by display width (a Hangul syllable takes 2 columns)
	t=$1 w=$2
	c=$(printf '%s' "$t" | LC_ALL=C tr -d '\200-\277' | wc -c | tr -d ' ')   # UTF-8 characters, any locale
	h=$(printf '%s' "$t" | LC_ALL=C tr -cd '\352-\355' | wc -c | tr -d ' ')   # lead bytes of Hangul syllables
	c=$((c + h))
	printf '%s' "$t"
	while [ $c -lt $w ]; do printf ' '; c=$((c + 1)); done
}
menu() {   # $1 = installed ids; sets SELECTED
	cur=1
	sel=""
	for p in $ALL; do
		s=0
		case " $DEFAULTS $1 " in *" $p "*) s=1 ;; esac
		sel="$sel $s"
	done
	old=$(stty -g)
	trap 'stty "$old"; printf "\033[?25h"; rm -rf "$CAT"' EXIT INT TERM
	stty -icanon -echo min 1 time 0
	printf '\033[?25l'
	rule="  ──────────────────────────────────────────────────────────────────────"
	while :; do
		printf '\033[H\033[2J\n  \033[1m%s\033[0m   [%s]\n%s\n' "$(m title)" "$(m lang)" "$rule"
		printf '        %s %s\n' "$(pad "$(m col_name)" 17)" "$(m col_desc)"
		i=1
		for p in $ALL; do
			s=$(echo $sel | cut -d' ' -f$i)
			box="[ ]"; [ "$s" = 1 ] && box="[x]"
			st=""; case " $1 " in *" $p "*) st="  ($(m installed))" ;; esac
			row="$(pad "$p" 17) $(pad "$(cf $i short_$LANG_UI)" 38)$st"
			if [ $i = $cur ]; then printf '  \033[7m> %s %s\033[0m\n' "$box" "$row"
			else printf '    %s %s\n' "$box" "$row"; fi
			i=$((i + 1))
		done
		p=$(echo $ALL | cut -d' ' -f$cur)
		tags=""
		case " $DEFAULTS " in *" $p "*) tags="$(m default)" ;; esac
		case " $1 " in *" $p "*) tags="${tags:+$tags · }$(m installed)" ;; esac
		printf '%s\n  \033[1m%s\033[0m%s\n' "$rule" "$p" "${tags:+   ($tags)}"
		cf $cur detail_$LANG_UI | tr '|' '\n' | while IFS= read -r line; do printf '    %s\n' "$line"; done
		printf '%s\n  %s\n' "$rule" "$(m keys)"
		k=$(dd bs=1 count=1 2>/dev/null)
		if [ "$k" = "$(printf '\033')" ]; then
			k2=$(dd bs=1 count=1 2>/dev/null); k3=$(dd bs=1 count=1 2>/dev/null)
			case "$k2$k3" in "[A"|"OA") [ $cur -gt 1 ] && cur=$((cur - 1)) ;; "[B"|"OB") [ $cur -lt $NMODS ] && cur=$((cur + 1)) ;; esac
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
			j|J) [ $cur -lt $NMODS ] && cur=$((cur + 1)) ;;
			l|L) if [ "$LANG_UI" = ko ]; then LANG_UI=en; else LANG_UI=ko; fi ;;
			q|Q) stty "$old"; printf '\033[?25h\n'; echo "$(m cancel)"; exit 0 ;;
			""|"$(printf '\r')") break ;;
		esac
	done
	stty "$old"; printf '\033[?25h\n'; trap 'rm -rf "$CAT"' EXIT; trap - INT TERM
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

# 2. What is installed, then choose (menu on a terminal; --packages / --yes or no terminal: no menu).
VLIST=$($SSH "$TARGET" "/home/root/.vellum/bin/vellum list 2>/dev/null | grep -F '[installed]' | cut -d' ' -f1" 2>/dev/null |
	sed 's/-[0-9][^-]*-r[0-9]*$//' | tr '\n' ' ' || true)
INSTALLED=""
i=1
while [ $i -le $NMODS ]; do
	id=$(cf $i id)
	if [ "$(cf $i type)" = vellum ]; then
		case " $VLIST " in *" $(cf $i package) "*) INSTALLED="$INSTALLED $id" ;; esac
	elif [ -n "$(cf $i check)" ] && $SSH "$TARGET" "$(cf $i check)" 2>/dev/null; then
		INSTALLED="$INSTALLED $id"
	fi
	i=$((i + 1))
done
if [ -n "$PICK" ]; then
	CHOSEN=$PICK
elif [ -n "$YES" ] || [ ! -t 0 ] || [ ! -t 1 ]; then
	CHOSEN=$DEFAULTS
else
	menu "$INSTALLED"
	CHOSEN=$SELECTED
fi
PACKAGES="" RELEASES=""
for id in $CHOSEN; do
	i=$(idx "$id")
	[ -n "$i" ] || die "$(m unknown) $id"
	if [ "$(cf $i type)" = vellum ]; then PACKAGES="$PACKAGES $(cf $i package)"; else RELEASES="$RELEASES $i"; fi
	for d in $(cf $i needs); do case " $PACKAGES " in *" $d "*) ;; *) PACKAGES="$PACKAGES $d" ;; esac; done
done
PACKAGES=${PACKAGES# }

# 3. Vellum (skipped when already installed). The bootstrap is checked against the hash in Vellum's README.
if $SSH "$TARGET" '[ -x /home/root/.vellum/bin/vellum ]'; then
	say "$(m vellum_ok)"
else
	say "$(m vellum)"
	curl -fsSL "$BOOTSTRAP_URL" -o "$CAT/bootstrap.sh"
	want=$(curl -fsSL "$VELLUM_README" | sed -n 's/.*echo "\([0-9a-f]\{64\}\)  bootstrap.sh".*/\1/p' | head -n 1)
	if command -v sha256sum >/dev/null 2>&1; then got=$(sha256sum "$CAT/bootstrap.sh" | cut -d' ' -f1)
	else got=$(shasum -a 256 "$CAT/bootstrap.sh" | cut -d' ' -f1); fi
	[ -n "$want" ] && [ "$want" = "$got" ] || die "$(m checksum) ($got, expected $want)"
	$SSH "$TARGET" 'cat > /tmp/vellum-bootstrap.sh && sh /tmp/vellum-bootstrap.sh; r=$?; rm -f /tmp/vellum-bootstrap.sh; exit $r' \
		< "$CAT/bootstrap.sh" || die "$(m vellum_fail)"
fi

# 4. This package repository and its signing key (downloaded here, so the tablet needs no TLS certificates).
say "$(m repo)"
curl -fsSL "$REPO/lorancecall-rmpp.rsa.pub" |
	$SSH "$TARGET" 'cat > /home/root/.vellum/etc/apk/keys/lorancecall-rmpp.rsa.pub'
$SSH "$TARGET" "grep -qxF '$REPO' /home/root/.vellum/etc/apk/repositories || echo '$REPO' >> /home/root/.vellum/etc/apk/repositories"

# 5. Vellum packages, then release mods. The tablet's screen restarts once or twice.
if [ -n "$PACKAGES" ]; then
	say "$(m installing) $PACKAGES"
	$SSH "$TARGET" "/home/root/.vellum/bin/vellum update && /home/root/.vellum/bin/vellum add $PACKAGES" ||
		die "$(m install_fail)"
fi
for i in $RELEASES; do
	id=$(cf $i id) repo=$(cat "$CAT/$i.repo")
	say "$(m release) $id ($repo)"
	mkdir -p "$CAT/rel-$i"
	for a in $(cf $i assets); do
		curl -fsSL "https://github.com/$repo/releases/latest/download/$a" -o "$CAT/rel-$i/$a" || die "$(m release_fail) ($a)"
	done
	dir=/home/root/.cache/rmpp-mods/$id
	$SSH "$TARGET" "rm -rf $dir && mkdir -p $dir"
	for a in $(cf $i assets); do $SSH "$TARGET" "cat > $dir/$a" < "$CAT/rel-$i/$a"; done
	$SSH "$TARGET" "cd $dir && sh rmpp-install.sh; r=\$?; cd / && rm -rf $dir; exit \$r" || die "$(m install_fail) ($id)"
done
[ -n "$PACKAGES$RELEASES" ] || say "$(m nothing)"

# 6. After a reMarkable OS update the files in the root file system are gone: restore them.
if [ -n "$VLIST$PACKAGES" ] && $SSH "$TARGET" '[ ! -x /usr/lib/rmpp-preload/launch ] && [ -x /home/root/.vellum/bin/vellum ]'; then
	say "$(m reenable)"
	$SSH "$TARGET" '/home/root/.vellum/bin/vellum reenable' || die "$(m reenable_fail)"
fi

say "$(m done)"
echo "$(m again)"
echo "$(m remove) ssh -i $KEY $TARGET /home/root/.vellum/bin/vellum del <package>"
