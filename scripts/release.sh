#!/usr/bin/env bash
# ==============================================================================
# release.sh — bump the SuperFedora version, commit, tag, push, publish release
# ==============================================================================
# Usage:
#   scripts/release.sh <patch|minor|major|X.Y.Z> "<summary>" [notes-file]
#
# Every change to SuperFedora ships as a release:
#   1. VERSION is bumped and CHANGELOG's [Unreleased] section becomes the notes
#   2. Everything in the working tree is committed as "release: vX.Y.Z — summary"
#   3. An annotated tag vX.Y.Z is created
#   4. main and the tag are pushed, and a GitHub release is published
# ==============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$(realpath "$0")")/.." && pwd)"
cd "$REPO_DIR"

BUMP="${1:-}"
SUMMARY="${2:-}"
NOTES_FILE="${3:-}"

if [[ -z "$BUMP" || -z "$SUMMARY" ]]; then
    sed -n '4,6p' "$0" | sed 's/^# \{0,1\}//'
    exit 2
fi

CURRENT="$(tr -d '[:space:]' < VERSION)"
IFS=. read -r MAJ MIN PAT <<< "$CURRENT"

case "$BUMP" in
    patch) NEW="$MAJ.$MIN.$((PAT + 1))" ;;
    minor) NEW="$MAJ.$((MIN + 1)).0" ;;
    major) NEW="$((MAJ + 1)).0.0" ;;
    [0-9]*.[0-9]*.[0-9]*) NEW="$BUMP" ;;
    *) echo "error: bump must be patch, minor, major or X.Y.Z" >&2; exit 2 ;;
esac

TAG="v$NEW"
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    echo "error: tag $TAG already exists" >&2
    exit 1
fi

# Sanity: shell scripts must parse before anything is published.
bash -n bin/superfedora || { echo "error: syntax check failed: bin/superfedora" >&2; exit 1; }
while IFS= read -r -d '' f; do
    bash -n "$f" || { echo "error: syntax check failed: $f" >&2; exit 1; }
done < <(find . -path ./.git -prune -o -name '*.sh' -type f -print0)

# What ships must be what is running: the live system must match dotfiles/.
# Set SUPERFEDORA_SKIP_DRIFT=1 when releasing from a machine that isn't the test box.
if [[ "${SUPERFEDORA_SKIP_DRIFT:-0}" != 1 ]] && ! lib/install-dotfiles.sh --check; then
    echo "error: live system differs from dotfiles/ — deploy (lib/install-dotfiles.sh) or copy live changes into the repo first" >&2
    exit 1
fi

# Release notes: the "## [Unreleased]" CHANGELOG section (or an explicit file)
NOTES="$(mktemp)"
trap 'rm -f "$NOTES"' EXIT
if [[ -n "$NOTES_FILE" && -f "$NOTES_FILE" ]]; then
    cp "$NOTES_FILE" "$NOTES"
else
    awk '/^## \[Unreleased\]/{f=1;next} /^## /{f=0} f' CHANGELOG.md | sed '/./,$!d' > "$NOTES"
fi
if ! grep -q '[^[:space:]]' "$NOTES"; then
    echo "error: CHANGELOG.md has no entries under '## [Unreleased]'" >&2
    exit 1
fi

echo "$NEW" > VERSION
sed -i "s/^## \[Unreleased\]/## [Unreleased]\n\n## [$NEW] — $(date +%F)/" CHANGELOG.md

# Regenerate docs derived from the shipped config
python3 scripts/gen-keybindings-doc.py

git add -A
git commit -q -m "release: $TAG — $SUMMARY"
git tag -a "$TAG" -m "SuperFedora $TAG — $SUMMARY"
git push -q origin HEAD
git push -q origin "$TAG"

gh release create "$TAG" --title "SuperFedora $TAG — $SUMMARY" --notes-file "$NOTES"

# Sync release version and installer to sibling superfedora.github.io repo if present
PAGES_DIR="$(dirname "$REPO_DIR")/superfedora.github.io"
if [[ -d "$PAGES_DIR/.git" ]]; then
    echo "Syncing release $TAG to superfedora.github.io…"
    echo "$NEW" > "$PAGES_DIR/VERSION"
    cp install.sh "$PAGES_DIR/install.sh"
    git -C "$PAGES_DIR" add VERSION install.sh
    git -C "$PAGES_DIR" commit -q -m "release: sync $TAG" 2>/dev/null || true
    git -C "$PAGES_DIR" push -q origin main 2>/dev/null || true
fi

# Record the released version as installed on this (test) machine
lib/install-dotfiles.sh --no-reload >/dev/null

echo "Released $TAG"
