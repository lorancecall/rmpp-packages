#!/bin/sh
# Build one package with vbuild and sign it with the lorancecall-rmpp key.
# Usage: scripts/build-package.sh <package> [arch]     (adapted from vellum-dev/vellum, GPL-3.0)
set -e
PACKAGE="$1"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$ROOT/packages/$PACKAGE"
[ -d "$DIR" ] || { echo "no package $PACKAGE"; exit 1; }
ARCH="${2:-aarch64}"
grep -q '^arch="noarch"' "$DIR/VELBUILD" && ARCH=noarch
KEY=lorancecall-rmpp
[ -f "$ROOT/keys/$KEY.rsa" ] || { echo "missing keys/$KEY.rsa"; exit 1; }
mkdir -p ~/.config/vbuild "$ROOT/dist/$ARCH"
cp "$ROOT/keys/$KEY.rsa" "$ROOT/keys/$KEY.rsa.pub" ~/.config/vbuild/
SOURCE_DATE_EPOCH=$(git -C "$ROOT" log -1 --format=%ct -- "packages/$PACKAGE")
WORK=$(mktemp -d)
cp -r "$DIR/." "$WORK"
SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH VBUILD_KEY_NAME=$KEY CARCH=$ARCH vbuild -C "$WORK" all
cp -r "$WORK/dist/." "$ROOT/dist/"
ls -la "$ROOT/dist/"*/*.apk
