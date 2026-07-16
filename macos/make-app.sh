#!/bin/sh
# 把 SwiftPM 产物组装成 Translator.app。
# 菜单栏常驻（LSUIElement）与开机自启（SMAppService）都要求以 .app bundle 形式运行。
set -e
cd "$(dirname "$0")"

swift build -c release

APP=Translator.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Translator "$APP/Contents/MacOS/Translator"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

echo "已生成 macos/$APP —— 建议移入 /Applications 后打开（辅助功能授权与开机自启按签名+路径识别，固定路径可避免重复授权）"
