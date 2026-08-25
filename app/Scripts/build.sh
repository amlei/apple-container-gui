#!/bin/zsh
# Build Container.app (release) from the SPM product.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Container"
BUNDLE_ID="com.container-gui.app"
BUILD_DIR=".build/release"
APP_DIR="build/$APP_NAME.app"

swift build -c release

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BUILD_DIR/ContainerGUI" "$APP_DIR/Contents/MacOS/$APP_NAME"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>Container</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key><true/>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>zh-Hans</string>
    </array>
</dict>
</plist>
PLIST

cp -R "$BUILD_DIR/ContainerGUI_ContainerGUI.bundle" "$APP_DIR/Contents/Resources/" 2>/dev/null || true

# Build the app icon (.icns) from the project logo.
LOGO="ContainerGUI/Resources/logo.png"
ICONSET="$(mktemp -d)"
sips -z 16 16 "$LOGO" --out "$ICONSET/icon_16x16.png" >/dev/null 2>&1
sips -z 32 32 "$LOGO" --out "$ICONSET/icon_16x16@2x.png" >/dev/null 2>&1
sips -z 32 32 "$LOGO" --out "$ICONSET/icon_32x32.png" >/dev/null 2>&1
sips -z 64 64 "$LOGO" --out "$ICONSET/icon_32x32@2x.png" >/dev/null 2>&1
sips -z 128 128 "$LOGO" --out "$ICONSET/icon_128x128.png" >/dev/null 2>&1
sips -z 256 256 "$LOGO" --out "$ICONSET/icon_128x128@2x.png" >/dev/null 2>&1
sips -z 256 256 "$LOGO" --out "$ICONSET/icon_256x256.png" >/dev/null 2>&1
sips -z 512 512 "$LOGO" --out "$ICONSET/icon_256x256@2x.png" >/dev/null 2>&1
sips -z 512 512 "$LOGO" --out "$ICONSET/icon_512x512.png" >/dev/null 2>&1
sips -z 1024 1024 "$LOGO" --out "$ICONSET/icon_512x512@2x.png" >/dev/null 2>&1
iconutil -c icns "$ICONSET" -o "$APP_DIR/Contents/Resources/AppIcon.icns" 2>/dev/null || true
rm -rf "$ICONSET"

codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || true
echo "Built $APP_DIR"
