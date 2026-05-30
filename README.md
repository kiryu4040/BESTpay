# 📱 BestPay - カード比較アプリ (v1.1)

> 普段使う複数の決済手段の中から、**「今、このお店で支払うとき、どの決済方法が一番お得か」** を瞬時に判定するAndroidアプリ。

---

## 🚨 v1.1の改善点

v1.0 で「Actions が走らない」問題があったため、以下を強化しました:

| 項目 | v1.0 | v1.1 |
|---|---|---|
| ワークフロー対応ブランチ | `main/master`のみ | **すべて**のブランチ |
| 手動実行ボタン | あり | **より目立つ表示** |
| 動作確認用ワークフロー | なし | **Hello World 追加**（5秒で完了、Actions有効性チェック用）|
| 権限設定 | デフォルト | **明示的に書き込み許可** |
| トラブルシューティング | あり | **TROUBLESHOOTING.md 新規追加** |

➡️ **問題が起きたら必ず [TROUBLESHOOTING.md](TROUBLESHOOTING.md) を参照してください**

---

## 🚀 APK入手の手順（最短ルート）

### ⚠️ 重要: `.github` フォルダのアップロード忘れに注意！

ブラウザのドラッグ&ドロップでは **`.` から始まる隠しフォルダが見落とされる** ことが多いです。
解決策は3つあります（詳細は [TROUBLESHOOTING.md](TROUBLESHOOTING.md)）:

- **🟢 おすすめ**: GitHub Web UI で `.github/workflows/build-apk.yml` を直接作成
- **🟡** OSの「隠しファイル表示」設定を有効にしてからアップロード
- **🔵** `git push` コマンドを使う

---

### ① GitHubアカウント作成 → リポジトリ作成 (5分)

1. https://github.com/signup でアカウント作成（無料）
2. 右上「+」→「New repository」
3. リポジトリ名: 何でも可（例: `bestpay`）
4. 「Add a README」のチェックは**外す**
5. 「Create repository」をクリック

### ② ソースをアップロード (3分)

#### 🟢 最も確実な方法 (Web UI):

ZIP内の `lib/`, `android/`, `pubspec.yaml` などをまずアップロード。
その後、**`.github/workflows/build-apk.yml` と `hello.yml` を Web UI で別途作成**。

詳細手順は [TROUBLESHOOTING.md > 解決策1](TROUBLESHOOTING.md) を参照。

#### 🔵 git コマンドの場合:

```bash
cd bestpay_app
git init
git add .                          # 隠しフォルダも自動で含まれる
git commit -m "Initial v1.1"
git branch -M main
git remote add origin https://github.com/<ユーザー名>/<リポジトリ名>.git
git push -u origin main
```

### ③ Actions が走るのを確認 (5〜10分)

1. リポジトリページ上部「**Actions**」タブをクリック
2. 「**Build Android APK**」「**Hello World (動作確認用)**」の2つが表示される
3. それぞれが自動実行されているはず
4. 緑のチェック ✅ になるまで待つ

### ④ スマホでAPKダウンロード (2分)

スマホブラウザでGitHubにログイン:
1. 自分のリポジトリ → **Actions** タブ
2. 成功した実行（緑チェック）をタップ
3. ページ下部の **Artifacts** → **BestPay-APK** をタップ
4. ZIPがダウンロード → 解凍 → `BestPay.apk` をタップしてインストール

### 💡 さらに簡単に: Releases機能
```bash
git tag v1.1.0
git push origin v1.1.0
```
→ GitHubのReleasesページに `BestPay.apk` が直リンクで出現！

---

## 🎯 アプリの機能

- **F1: 店舗検索＆ベスト決済提示** — 店舗名で検索→最適な決済方法と還元率をランキング表示
- **F2: 金額入力＆還元額計算** — 金額を入力すると各決済の実還元ポイント／円を自動計算
- **F3: 保有決済方法の管理** — ユーザー所有のカード／QR決済をON/OFFで管理
- **F4: 条件達成状況の管理** — Vポイントアッププログラム・PayPayステップ・楽天SPU等
- **F5: カスタムルール追加** — 独自の還元ルール（特定店舗×決済の還元率）を追加・編集
- **F6: カテゴリ別ブラウズ** — コンビニ／ファミレス／カフェ／ECなど10カテゴリ
- **F7: お気に入り店舗** — よく行く店をピン留めしてホームに表示
- **F8: 積立還元シミュレーション** — 月次／年次の還元ポイント予測
- **F9: データのエクスポート／インポート** — JSON形式でバックアップ／復元
- **F10: ダーク／ライトテーマ切り替え** — システム連動・手動切替

## 📦 搭載データ（仕様書セクション2〜6を完全反映）

- **9種類の決済方法**: Olive Gold / 三井住友NLゴールド / V NEOBANK Debit / 三菱UFJ / PayPay / VポイントPay / 楽天 / JCBカードW / メルカード
- **58店舗**: コンビニ6・ファミレス12・カフェ4・ドラッグストア5・100均2・EC6・スーパー6・百貨店5・交通8・ガソリン4
- **200+ の還元ルール**: 仕様書のマトリクスを完全反映
- **条件達成型還元**: Vポイントアップ最大20% / 三菱UFJポイントアップ最大20% / PayPayステップ / 楽天SPU 最大18倍 / LYPプレミアム / ウエル活

## 📊 計算ロジック

```
適用還元率 = 基本還元率 + 店舗特典 + 条件達成加算
還元額(円) = 利用額 × 適用還元率 / 100
```

詳細は `lib/utils/calculator.dart` を参照。

## 🛠 ローカルビルドの場合

Flutter 3.24.5 / Android SDK 34 / JDK 17 が必要です。

```bash
flutter pub get
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

詳細は `BUILD_INSTRUCTIONS.md` を参照。

## 📁 ファイル構成

```
bestpay_app/
├ .github/workflows/
│   ├ build-apk.yml      ← メインのAPKビルド
│   └ hello.yml          ← 動作確認用（5秒）
├ pubspec.yaml
├ android/               ← 完全な Android プロジェクトファイル
└ lib/                   ← 20 Dartファイル（全機能）
   ├ main.dart
   ├ models/
   ├ db/
   ├ providers/
   ├ screens/
   ├ widgets/
   └ utils/
```

## ⚠️ 注意事項

- 還元率は2026年5月時点の情報です
- 「最大○%」表記は条件達成時の値です。「条件管理」画面で達成状況を更新してください

---

*BestPay v1.1.0 - GitHub Actions対応強化版*
