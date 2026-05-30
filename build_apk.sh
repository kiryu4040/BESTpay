#!/bin/bash
# BestPay ローカルビルドスクリプト (Flutterインストール済みの場合)
set -e

echo "=================================="
echo " BestPay APK Build Script"
echo "=================================="

if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter が見つかりません。"
    echo "   → GitHub Actions でビルドする方法: SETUP_GUIDE_JP.md を参照"
    exit 1
fi

echo "✅ Flutter: $(flutter --version | head -1)"

flutter pub get
flutter build apk --release

APK="build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$APK" ]; then
    echo ""
    echo "🎉 ビルド成功！"
    echo "📍 $APK ($(du -h "$APK" | cut -f1))"
    echo ""
    echo "📲 スマホへインストール: adb install $APK"
else
    echo "❌ ビルド失敗"
    exit 1
fi
