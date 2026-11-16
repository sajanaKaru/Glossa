#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

TAG="v1.1.0"
TITLE="Glossa v1.1.0 — Native macOS Translation & Grammar Polisher"
NOTES_FILE="RELEASE_NOTES.md"
REPO="sajanaKaru/LingoBar"

echo "=========================================================="
echo " Starting Glossa Official Release: ${TAG}"
echo " Repository: ${REPO}"
echo "=========================================================="

# 1. Package fresh assets
echo "==> Step 1: Packaging Glossa-Installer.dmg and Glossa-macOS.zip..."
./package.sh

if [ ! -f "Glossa-Installer.dmg" ] || [ ! -f "Glossa-macOS.zip" ]; then
    echo "ERROR: Release artifacts Glossa-Installer.dmg or Glossa-macOS.zip not found!" >&2
    exit 1
fi

# 2. Generate SHA-256 Checksums
echo "==> Step 2: Generating SHA-256 checksums..."
shasum -a 256 Glossa-Installer.dmg > Glossa-Installer.dmg.sha256
shasum -a 256 Glossa-macOS.zip > Glossa-macOS.zip.sha256

echo "Checksums generated:"
cat Glossa-Installer.dmg.sha256
cat Glossa-macOS.zip.sha256

# 3. Create Git Tag if not present
echo "==> Step 3: Checking git tag ${TAG}..."
if git rev-parse "${TAG}" >/dev/null 2>&1; then
    echo "Git tag ${TAG} already exists locally."
else
    echo "Creating git tag ${TAG}..."
    git tag -a "${TAG}" -m "${TITLE}"
fi

# 4. Push Git Tag to remote
echo "==> Step 4: Pushing tag ${TAG} to remote..."
git push origin "${TAG}" || {
    echo "Warning: git push tag failed or tag already exists on remote. Continuing..."
}

# 5. Publish to GitHub Releases using gh CLI
echo "==> Step 5: Publishing GitHub Release via gh CLI..."
if gh release view "${TAG}" --repo "${REPO}" >/dev/null 2>&1; then
    echo "GitHub Release ${TAG} already exists. Uploading/updating assets..."
    gh release upload "${TAG}" Glossa-Installer.dmg Glossa-macOS.zip Glossa-Installer.dmg.sha256 Glossa-macOS.zip.sha256 --repo "${REPO}" --clobber
    gh release edit "${TAG}" --repo "${REPO}" --title "${TITLE}" --notes-file "${NOTES_FILE}"
else
    echo "Creating new GitHub Release ${TAG}..."
    gh release create "${TAG}" \
        Glossa-Installer.dmg \
        Glossa-macOS.zip \
        Glossa-Installer.dmg.sha256 \
        Glossa-macOS.zip.sha256 \
        --repo "${REPO}" \
        --title "${TITLE}" \
        --notes-file "${NOTES_FILE}"
fi

echo "=========================================================="
echo " ✅ Glossa ${TAG} Released Successfully!"
echo " Release URL: https://github.com/${REPO}/releases/tag/${TAG}"
echo "=========================================================="
