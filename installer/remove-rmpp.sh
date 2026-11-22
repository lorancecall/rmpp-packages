#!/bin/sh
# Runs ON THE TABLET (install-rmpp.sh / install-rmpp.ps1 --uninstall send it over SSH): removes every rmpp add-on
# and every rmpp system file, so the tablet's system is stock again.
#
#   sh remove-rmpp.sh [--purge] [--vellum]
#     --purge   also delete the add-ons' settings and data in /home (Tailscale login, handwriting models, ...)
#     --vellum  also remove Vellum itself (only when no other Vellum packages are installed)
#
# 1. Vellum removes the rmpp packages it knows (their scripts clean up after themselves).
# 2. Whatever is left on the root file system is deleted: /usr/lib/rmpp (rmpp-preload 0.2+), xochitl's drop-in,
#    and the files older versions put in /usr/lib/rmpp-*, /usr/bin/rmpp-* and /usr/lib/systemd/system.
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

# 1. packages
if [ -x "$V" ]; then
	pkgs=$("$V" list 2>/dev/null | grep -F '[installed]' | cut -d' ' -f1 | sed 's/-[0-9][^-]*-r[0-9]*$//' |
		grep -E '^rmpp-(preload|refresh|bt|tailscale|lang|lang-.+|ridi|hwr)$' | tr '\n' ' ')
	if [ -n "$pkgs" ]; then
		echo "removing packages: $pkgs"
		if [ -n "$PURGE" ]; then "$V" purge $pkgs; else "$V" del $pkgs; fi || echo "warning: vellum could not remove everything; deleting the files below anyway"
	fi
fi

# 2. leftover system files
systemctl stop rmpp-restart-xochitl.timer rmpp-bt-reconnect.service rmpp-tailscaled.service rmpp-tailscale-ssh.socket 2>/dev/null || true
left=$(ls -d /usr/lib/rmpp /usr/lib/rmpp-* /usr/bin/rmpp-* /usr/lib/systemd/system/rmpp-* \
	/usr/lib/systemd/system/multi-user.target.wants/rmpp-* /usr/lib/systemd/system/xochitl.service.d/zz-rmpp-* 2>/dev/null)
if [ -n "$left" ]; then
	echo "removing system files:"
	echo "$left" | sed 's/^/  /'
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
if [ -n "$PURGE" ]; then
	rm -rf /home/root/.config/rmpp-* /home/root/.local/share/rmpp-* /home/root/.local/share/fonts/rmpp-lang
fi

# 3. Vellum itself (optional)
if [ -n "$VELLUM_TOO" ] && [ -x "$V" ]; then
	others=$("$V" list 2>/dev/null | grep -F '[installed]' | cut -d' ' -f1 | sed 's/-[0-9][^-]*-r[0-9]*$//' |
		grep -v -E '^(vellum|vellum-bash-completion|mount-utils|remarkable-os|rmpp)$' | tr '\n' ' ')
	if [ -n "$others" ]; then
		echo "keeping Vellum: other packages are installed ($others)"
	else
		"$V" self uninstall
	fi
fi
echo "rmpp removed"
