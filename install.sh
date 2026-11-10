#!/bin/sh
# Add the rmpp package repository to Vellum on a reMarkable Paper Pro, then install the packages.
# Run on the tablet:  wget -qO- https://lorancecall.github.io/rmpp-packages/install.sh | sh
set -e
REPO=https://lorancecall.github.io/rmpp-packages
V=/home/root/.vellum
[ -x "$V/bin/vellum" ] || { echo "Vellum is not installed. See https://github.com/vellum-dev/vellum-cli first."; exit 1; }
mkdir -p "$V/etc/apk/keys"
wget -qO "$V/etc/apk/keys/lorancecall-rmpp.rsa.pub" "$REPO/lorancecall-rmpp.rsa.pub"
grep -qxF "$REPO" "$V/etc/apk/repositories" || echo "$REPO" >> "$V/etc/apk/repositories"
"$V/bin/vellum" update
echo "Added $REPO. Install with:  vellum add rmpp-korean rmpp-bt"
