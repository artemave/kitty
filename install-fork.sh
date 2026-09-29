#!/usr/bin/env bash
# Installs (or updates) the latest release from
# https://github.com/artemave/kitty/releases into ~/.local/share/kitty-fork,
# and symlinks kitty/kitten into ~/.local/bin.
#
# Safe to re-run: it fetches whatever the latest release currently is, skips
# re-downloading if that version is already installed, and repoints the
# ~/.local/bin symlinks (and the "current" symlink) at it either way.

set -euo pipefail

REPO="artemave/kitty"
INSTALL_ROOT="$HOME/.local/share/kitty-fork"
BIN_DIR="$HOME/.local/bin"

mkdir -p "$INSTALL_ROOT" "$BIN_DIR"

echo "Checking latest release for $REPO..."
RELEASE_JSON=$(curl -fsSL "https://api.github.com/repos/$REPO/releases" | python3 -c '
import json, sys
releases = json.load(sys.stdin)
print(json.dumps(releases[0]) if releases else "")
')

if [ -z "$RELEASE_JSON" ]; then
    echo "No releases found for $REPO" >&2
    exit 1
fi

TAG=$(printf '%s' "$RELEASE_JSON" | python3 -c 'import json, sys; print(json.load(sys.stdin)["tag_name"])')
ASSET_URL=$(printf '%s' "$RELEASE_JSON" | python3 -c '
import json, sys
d = json.load(sys.stdin)
for a in d["assets"]:
    if a["name"].endswith(".tar.xz"):
        print(a["browser_download_url"])
        break
')

if [ -z "$ASSET_URL" ]; then
    echo "Release $TAG has no .tar.xz asset" >&2
    exit 1
fi

TARGET_DIR="$INSTALL_ROOT/$TAG"

if [ -d "$TARGET_DIR" ]; then
    echo "$TAG is already installed at $TARGET_DIR"
else
    TMP_TAR=$(mktemp --suffix=.tar.xz)
    trap 'rm -f "$TMP_TAR"' EXIT
    echo "Downloading $TAG..."
    curl -fsSL -o "$TMP_TAR" "$ASSET_URL"
    mkdir -p "$TARGET_DIR"
    echo "Extracting to $TARGET_DIR..."
    tar -xJf "$TMP_TAR" -C "$TARGET_DIR"
fi

ln -sfn "$TARGET_DIR" "$INSTALL_ROOT/current"

for bin in kitty kitten; do
    ln -sfn "$INSTALL_ROOT/current/kitty/launcher/$bin" "$BIN_DIR/$bin"
done

echo
echo "Installed $TAG"
echo "  $BIN_DIR/kitty  -> $TARGET_DIR/kitty/launcher/kitty"
echo "  $BIN_DIR/kitten -> $TARGET_DIR/kitty/launcher/kitten"

case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *)
        echo
        echo "Note: $BIN_DIR is not on your PATH. Add this to your shell rc file:"
        echo "  export PATH=\"$BIN_DIR:\$PATH\""
        ;;
esac
