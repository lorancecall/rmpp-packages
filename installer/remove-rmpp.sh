#!/bin/sh
# Runs ON THE TABLET (install-rmpp.sh / install-rmpp.ps1 --uninstall send it over SSH): removes every rmpp add-on
# and every rmpp system file, so the tablet's system is stock again.
#
#   sh remove-rmpp.sh [--purge] [--vellum]
#     --purge   also delete the add-ons' settings and data in /home (Tailscale login, handwriting models, ...)
#     --vellum  also remove Vellum itself (only when no other Vellum packages are installed)
#
# Nothing here names an add-on (except step 0, rmpp-lang's keyboard layouts): a new package needs no change here.
# 1. The packages are the installed ones that this package repository provides (`vellum policy` lists each
#    package's repositories), so the repository's index is the list. Each package removes its own files in its
#    VELBUILD (predeinstall), and its settings and data when Vellum purges it (VELLUM_PURGE=1).
#    Packages from other repositories stay; so does rmpp-preload while one of them needs it.
# 2. Once rmpp-preload is gone, whatever is left on the root file system is deleted: /usr/lib/rmpp (rmpp-preload's
#    layout, shared by every add-on), xochitl's drop-in, and what older versions put in /usr/lib/rmpp-*,
#    /usr/bin/rmpp-* and /usr/lib/systemd/system.
# Never `systemctl stop xochitl` (it powers the tablet off). Plain remount of /: Vellum's mount-rw would also
# drop the /etc/dropbear bind mount (SSH host key) until the next boot.
PURGE="" VELLUM_TOO=""
for a in "$@"; do
	case "$a" in
		--purge) PURGE=1 ;;
		--vellum) VELLUM_TOO=1 ;;
	esac
done
V=/home/root/.vellum/bin/vellum
REPO=https://lorancecall.github.io/rmpp-packages
installed() { "$V" list 2>/dev/null | grep -F '[installed]' | cut -d' ' -f1 | sed 's/-[0-9][^-]*-r[0-9]*$//'; }

# 0. rmpp-lang's keyboard layouts (the one rmpp-lang detail here): xochitl keeps layout ids in its keyboard setting
#    after the layout is gone and then shows an empty keyboard. The language add-ons take their layouts out of the
#    setting when they are removed (since pkgrel 1); this covers add-ons installed before that. Noted before the
#    packages go (<code>:<layout ids> of each add-on with layouts), dropped below once that add-on's layouts are gone.
LANGS=/usr/lib/rmpp/rmpp-lang/languages
lang_layouts=""
for r in "$LANGS"/*.rcc; do
	[ -e "$r" ] || continue
	c=$(basename "$r" .rcc)
	f=/home/root/.local/share/rmpp-lang/languages/$c/language.conf
	[ -f "$f" ] && lang_layouts="$lang_layouts $c:$(sed -n 's/^layouts[^=]*=//p' "$f" | tr ', \n' ':::' | tr -s ':')"
done
drop_keyboard_layouts() {   # same steps as the add-ons' predeinstall (scripts/lang-addons.py)
	C=/home/root/.config/remarkable/xochitl.conf
	if [ -f "$C" ] && grep -q '^Keyboard=' "$C"; then
		awk -v drop=" $* " '/^Keyboard=/ { s = substr($0, 10); gsub(/"/, "", s); n = split(s, a, /, */); v = ""
			for (i = 1; i <= n; i++) if (a[i] != "" && index(drop, " " a[i] " ") == 0) v = v (v == "" ? "" : ", ") a[i]
			$0 = "Keyboard=" (v == "" ? "en_US" : v) } { print }' "$C" > "$C.rmpp-new" &&
			{ cmp -s "$C" "$C.rmpp-new" || cp -f "$C.rmpp-new" "$C"; }
		rm -f "$C.rmpp-new"
	fi
}

# 1. packages
if [ -x "$V" ]; then
	all=$(installed | tr '\n' ' ')
	ours=""
	for p in $all; do
		"$V" policy "$p" 2>/dev/null | grep -qxF "    $REPO" && ours="$ours $p"
	done
	if [ -z "$ours" ] && ! grep -qxF "$REPO" /home/root/.vellum/etc/apk/repositories 2>/dev/null; then
		# the repository entry is already gone, so apk no longer knows where packages came from: rmpp-* by name
		ours=$(installed | grep -E '^rmpp-.+$' | tr '\n' ' ')
	fi
	if [ -n "$ours" ]; then
		echo "removing packages:$ours"
		addons=$(echo $ours | tr ' ' '\n' | grep -vx rmpp-preload | tr '\n' ' ')
		if [ -n "$addons" ]; then
			if [ -n "$PURGE" ]; then "$V" purge $addons; else "$V" del $addons; fi ||
				echo "warning: vellum could not remove everything"
		fi
		gone=""
		for e in $lang_layouts; do
			[ -e "$LANGS/${e%%:*}.rcc" ] || gone="$gone $(echo "${e#*:}" | tr ':' ' ')"
		done
		[ -z "${gone# }" ] || drop_keyboard_layouts $gone
		# rmpp-preload last, on its own: apk keeps it (and says why) while a package of another repository needs it
		case " $ours " in *" rmpp-preload "*)
			if [ -n "$PURGE" ]; then "$V" purge rmpp-preload; else "$V" del rmpp-preload; fi ||
				echo "keeping rmpp-preload: another package needs it" ;;
		esac
	fi
	if ! installed | grep -qx rmpp-preload; then
		# this repository's entry and signing key (other repositories stay)
		sed -i "\#^$REPO\$#d" /home/root/.vellum/etc/apk/repositories 2>/dev/null || true
		rm -f /home/root/.vellum/etc/apk/keys/lorancecall-rmpp.rsa.pub
	fi
fi

# 2. leftover system files (only once rmpp-preload is gone: other repositories' add-ons may still use the layout)
if [ -x "$V" ] && installed | grep -qx rmpp-preload; then
	echo "rmpp-preload stays (needed by another package): /usr/lib/rmpp is kept"
else
	left=$(ls -d /usr/lib/rmpp /usr/lib/rmpp-* /usr/bin/rmpp-* /usr/lib/systemd/system/rmpp-* \
		/usr/lib/systemd/system/multi-user.target.wants/rmpp-* /usr/lib/systemd/system/xochitl.service.d/zz-rmpp-* 2>/dev/null)
	if [ -n "$left" ]; then
		echo "removing system files:"
		echo "$left" | sed 's/^/  /'
		systemctl stop 'rmpp-*' 2>/dev/null || true
		mount -o remount,rw /
		# unload first: no drop-in, no links, restart xochitl, then delete (/ can go back to read-only afterwards)
		rm -f /usr/lib/systemd/system/xochitl.service.d/zz-rmpp-* /usr/lib/systemd/system/multi-user.target.wants/rmpp-*
		rm -f /usr/lib/systemd/system/rmpp-*
		rm -f /run/systemd/system/rmpp-*
		systemctl daemon-reload
		systemctl reset-failed xochitl 2>/dev/null || true
		systemctl restart xochitl
		sleep 3
		rm -rf /usr/lib/rmpp /usr/lib/rmpp-* /usr/bin/rmpp-*
		sync
		mount -o remount,ro / || echo "note: / is still read-write until the next restart"
	fi
fi
rm -rf /home/root/.cache/rmpp-mods   # rmpp setup's download folder for release-type mods
if [ -n "$PURGE" ]; then
	# what the packages' own purge left (older versions purged nothing): the folders named after each removed package
	for p in $ours; do
		rm -rf "/home/root/.config/$p" "/home/root/.local/share/$p"
	done
fi

# 3. Vellum itself (optional)
if [ -n "$VELLUM_TOO" ] && [ -x "$V" ]; then
	others=$(installed | grep -v -E '^(vellum|vellum-bash-completion|mount-utils|remarkable-os|rmpp)$' | tr '\n' ' ')
	if [ -n "$others" ]; then
		echo "keeping Vellum: other packages are installed ($others)"
	else
		"$V" self uninstall
	fi
fi
echo "rmpp removed"
