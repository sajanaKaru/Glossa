#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

APP_NAME="Glossa"
APP_BUNDLE="${APP_NAME}.app"
DMG_VOLUME_NAME="${APP_NAME}"
DMG_NAME="${APP_NAME}-Installer.dmg"
ZIP_NAME="${APP_NAME}-macOS.zip"
TEMP_DMG=".${APP_NAME}-temp.dmg"
MOUNT_DIR="/Volumes/${DMG_VOLUME_NAME}"
BG_IMAGE="Resources/installer_background.png"

echo "==> [Package] Ensuring fresh build of ${APP_BUNDLE}..."
./build.sh

if [ ! -d "${APP_BUNDLE}" ]; then
    echo "ERROR: ${APP_BUNDLE} not found!" >&2
    exit 1
fi

if [ ! -f "${BG_IMAGE}" ]; then
    echo "ERROR: Background image '${BG_IMAGE}' not found!" >&2
    exit 1
fi

echo "==> [Package] Cleaning up existing packaging artifacts..."
rm -f "${DMG_NAME}" "${ZIP_NAME}" "${TEMP_DMG}"

# Ensure no stale volume is mounted
if [ -d "${MOUNT_DIR}" ]; then
    echo "==> Unmounting stale volume at ${MOUNT_DIR}..."
    hdiutil detach "${MOUNT_DIR}" -force || true
    sleep 1
fi

cleanup() {
    local sig="${1:-0}"
    echo "==> [Package Cleanup] Cleaning temporary resources (signal: ${sig})..."
    if [ -d "${MOUNT_DIR}" ]; then
        hdiutil detach "${MOUNT_DIR}" -force 2>/dev/null || true
    fi
    rm -f "${TEMP_DMG}"
    if [ "${sig}" -ne 0 ]; then
        exit 1
    fi
}

trap 'cleanup 1' HUP
trap 'cleanup 2' INT
trap 'cleanup 15' TERM

echo "==> [Package] Creating temporary read-write DMG volume..."
hdiutil create -size 40m -fs HFS+ -volname "${DMG_VOLUME_NAME}" "${TEMP_DMG}"

echo "==> [Package] Mounting temporary DMG..."
hdiutil attach "${TEMP_DMG}" -noautoopen -mountpoint "${MOUNT_DIR}"

echo "==> [Package] Copying ${APP_BUNDLE} and creating Applications symlink..."
cp -R "${APP_BUNDLE}" "${MOUNT_DIR}/"
ln -s /Applications "${MOUNT_DIR}/Applications"

echo "==> [Package] Injecting installer background image..."
mkdir -p "${MOUNT_DIR}/.background"
cp -f "${BG_IMAGE}" "${MOUNT_DIR}/.background/background.png"

echo "==> [Package] Configuring Finder window layout via AppleScript..."
osascript <<EOF || true
tell application "Finder"
    tell disk "${DMG_VOLUME_NAME}"
        open
        delay 1
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 800, 520}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 112
        try
            set background picture of viewOptions to file "background.png" of folder ".background" of disk "${DMG_VOLUME_NAME}"
        end try
        set position of item "${APP_BUNDLE}" of container window to {160, 205}
        set position of item "Applications" of container window to {440, 205}
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF

echo "==> [Package] Finalizing disk volume..."
sync

echo "==> [Package] Detaching temporary DMG volume..."
detached=0
for i in {1..5}; do
    if hdiutil detach "${MOUNT_DIR}" 2>/dev/null; then
        detached=1
        break
    fi
    echo "Waiting for disk to be released (attempt $i/5)..."
    sleep 2
done

if [ "$detached" -eq 0 ]; then
    echo "Force detaching volume ${MOUNT_DIR}..."
    hdiutil detach "${MOUNT_DIR}" -force
fi

echo "==> [Package] Converting to compressed release DMG (${DMG_NAME})..."
hdiutil convert "${TEMP_DMG}" -format UDZO -imagekey zlib-level=9 -o "${DMG_NAME}"
rm -f "${TEMP_DMG}"

echo "==> [Package] Building portable ZIP distribution package (${ZIP_NAME})..."
ditto -c -k --keepParent "${APP_BUNDLE}" "${ZIP_NAME}"

# Disarm signal traps
trap - HUP INT TERM

echo "==> [Package] Verifying generated distribution packages..."
if [ ! -s "${DMG_NAME}" ]; then
    echo "ERROR: DMG package '${DMG_NAME}' is missing or empty!" >&2
    exit 1
fi

if [ ! -s "${ZIP_NAME}" ]; then
    echo "ERROR: ZIP package '${ZIP_NAME}' is missing or empty!" >&2
    exit 1
fi

echo "==> [Package] Distribution packages successfully created:"
ls -lh "${DMG_NAME}" "${ZIP_NAME}"
