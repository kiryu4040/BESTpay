# ビルド手順

## 🚀 推奨: GitHub Actions（PC環境構築不要）

➡️ **[SETUP_GUIDE_JP.md](SETUP_GUIDE_JP.md) を参照してください**

GitHubにpushするだけで、自動的にAPKがビルドされます。スマホで直接ダウンロード可能。

---

## 🛠 ローカルでビルドする場合

### 必要環境
- Flutter SDK 3.24.x
- Android SDK (API 34)
- OpenJDK 17

### コマンド

```bash
flutter pub get
flutter build apk --release
```

成果物:
```
build/app/outputs/flutter-apk/app-release.apk
```

### 環境セットアップ

#### Flutter インストール
https://docs.flutter.dev/get-started/install を参照

#### Android SDK セットアップ
- Android Studio を入れるのが簡単
- または `sdkmanager` で必要なものだけ:
  ```bash
  sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"
  flutter doctor --android-licenses
  ```

### スマホにインストール
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

または APK をスマホに転送→タップしてインストール。
