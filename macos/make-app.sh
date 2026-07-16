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
mkdir -p "$APP/Contents/Resources"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"   # 重新生成：swift make-icon.swift + iconutil

# 优先用本机的开发者证书：签名身份稳定，辅助功能授权可跨重建保留；
# ad-hoc 签名每次构建都变，每次替换应用都会把 TCC 授权作废。
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' 'NR==1 {print $2}')
codesign --force --sign "${IDENTITY:--}" "$APP"
echo "签名身份：${IDENTITY:-ad-hoc（未找到开发者证书）}"

echo "已生成 macos/$APP —— 建议移入 /Applications 后打开（辅助功能授权与开机自启按签名+路径识别，固定路径可避免重复授权）"
