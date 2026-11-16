#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

APP_NAME="LingoBar"
APP_BUNDLE="${APP_NAME}.app"
DMG_NAME="${APP_NAME}-Installer.dmg"
ZIP_NAME="${APP_NAME}-macOS.zip"
DMG_STAGING=".dmg_staging"

echo "==> [Package] Ensuring fresh build of ${APP_BUNDLE}..."
./build.sh

echo "==> [Package] Preparing DMG staging environment..."
rm -rf "${DMG_STAGING}" "${DMG_NAME}" "${ZIP_NAME}"
mkdir -p "${DMG_STAGING}"

echo "==> [Package] Copying ${APP_BUNDLE} to staging..."
cp -R "${APP_BUNDLE}" "${DMG_STAGING}/"

echo "==> [Package] Creating /Applications symlink for drag-and-drop installation..."
ln -s /Applications "${DMG_STAGING}/Applications"

echo "==> [Package] Building compressed DMG installer (${DMG_NAME})..."
hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_STAGING}" -ov -format UDZO "${DMG_NAME}"

echo "==> [Package] Building portable ZIP archive (${ZIP_NAME})..."
ditto -c -k --keepParent "${APP_BUNDLE}" "${ZIP_NAME}"

echo "==> [Package] Cleaning up staging directory..."
rm -rf "${DMG_STAGING}"

echo "==> [Package] Verifying distribution packages..."
if [ ! -s "${DMG_NAME}" ]; then
    echo "ERROR: DMG creation failed or file is empty!" >&2
    exit 1
fi

if [ ! -s "${ZIP_NAME}" ]; then
    echo "ERROR: ZIP creation failed or file is empty!" >&2
    exit 1
fi

echo "==> [Package] Successfully generated distribution packages:"
ls -lh "${DMG_NAME}" "${ZIP_NAME}"
