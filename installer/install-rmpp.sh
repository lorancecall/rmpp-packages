#!/bin/sh
# Install Vellum and the rmpp packages (Korean keyboard, Bluetooth) on a reMarkable Paper Pro.
# Runs on your computer (Linux or macOS). Needs: ssh, ssh-keygen, curl.
#
#   curl -fsSL https://lorancecall.github.io/rmpp-packages/install-rmpp.sh -o install-rmpp.sh
#   sh install-rmpp.sh [tablet-address]
#
# Before you start, turn on developer mode on the tablet. The root password is shown in
# Settings > General > Help > About > Copyrights and licenses.
set -e

REPO=https://lorancecall.github.io/rmpp-packages
VELLUM_README=https://raw.githubusercontent.com/vellum-dev/vellum-cli/main/README.md
BOOTSTRAP_URL=https://github.com/vellum-dev/vellum-cli/releases/latest/download/bootstrap.sh
PACKAGES="rmpp-korean rmpp-bt"
KEY="$HOME/.ssh/id_ed25519_rmpp"

say() { printf '\n==> %s\n' "$*"; }
die() { printf '\nError: %s\n' "$*" >&2; exit 1; }
for c in ssh ssh-keygen curl; do command -v "$c" >/dev/null 2>&1 || die "$c is not installed"; done

HOST=${1:-}
if [ -z "$HOST" ]; then
	printf 'Tablet address [10.11.99.1 over USB, or its Wi-Fi IP]: '
	read -r HOST
	HOST=${HOST:-10.11.99.1}
fi
TARGET="root@$HOST"
SSH="ssh -i $KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"

# 1. SSH key: the password is asked once, then the key is used.
if [ ! -f "$KEY" ]; then
	say "Creating an SSH key for the tablet ($KEY)"
	mkdir -p "$HOME/.ssh"
	ssh-keygen -q -t ed25519 -N "" -C "rmpp" -f "$KEY"
fi
if ! $SSH -o BatchMode=yes -o ConnectTimeout=8 "$TARGET" true 2>/dev/null; then
	say "Logging in to $HOST. Type the tablet's root password when asked."
	$SSH -o ConnectTimeout=8 "$TARGET" \
		'umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys' < "$KEY.pub" ||
		die "could not log in to $HOST"
	$SSH -o BatchMode=yes "$TARGET" true || die "the key was not accepted"
fi
say "Logged in to $HOST"

# 2. Vellum (skipped when already installed). The bootstrap is checked against the hash in Vellum's README.
if $SSH "$TARGET" '[ -x /home/root/.vellum/bin/vellum ]'; then
	say "Vellum is already installed"
else
	say "Installing Vellum"
	tmp=$(mktemp -d)
	curl -fsSL "$BOOTSTRAP_URL" -o "$tmp/bootstrap.sh"
	want=$(curl -fsSL "$VELLUM_README" | sed -n 's/.*echo "\([0-9a-f]\{64\}\)  bootstrap.sh".*/\1/p' | head -n 1)
	if command -v sha256sum >/dev/null 2>&1; then got=$(sha256sum "$tmp/bootstrap.sh" | cut -d' ' -f1)
	else got=$(shasum -a 256 "$tmp/bootstrap.sh" | cut -d' ' -f1); fi
	[ -n "$want" ] && [ "$want" = "$got" ] || die "Vellum bootstrap checksum mismatch ($got, expected $want)"
	$SSH "$TARGET" 'cat > /tmp/vellum-bootstrap.sh && sh /tmp/vellum-bootstrap.sh; r=$?; rm -f /tmp/vellum-bootstrap.sh; exit $r' \
		< "$tmp/bootstrap.sh" || die "Vellum installation failed"
	rm -rf "$tmp"
fi

# 3. This package repository and its signing key (downloaded here, so the tablet needs no TLS certificates).
say "Adding the rmpp package repository"
curl -fsSL "$REPO/lorancecall-rmpp.rsa.pub" |
	$SSH "$TARGET" 'cat > /home/root/.vellum/etc/apk/keys/lorancecall-rmpp.rsa.pub'
$SSH "$TARGET" "grep -qxF '$REPO' /home/root/.vellum/etc/apk/repositories || echo '$REPO' >> /home/root/.vellum/etc/apk/repositories"

# 4. Packages. The tablet's screen restarts once or twice while they install.
say "Installing $PACKAGES (the tablet's screen will restart)"
$SSH "$TARGET" "/home/root/.vellum/bin/vellum update && /home/root/.vellum/bin/vellum add $PACKAGES" ||
	die "package installation failed"

# 5. After a reMarkable OS update the files in the root file system are gone: restore them.
if $SSH "$TARGET" '[ ! -x /usr/lib/rmpp-preload/launch ]'; then
	say "Restoring system files after an OS update (vellum reenable)"
	$SSH "$TARGET" '/home/root/.vellum/bin/vellum reenable' || die "vellum reenable failed"
fi

say "Done. On the tablet: Settings > Language & keyboard > Korean; Settings > Bluetooth."
echo "After a reMarkable OS update, run this script again (it runs 'vellum reenable')."
