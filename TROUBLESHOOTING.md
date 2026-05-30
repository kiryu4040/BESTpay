# 🔧 トラブルシューティング: Actionsが見つからない/動かない時

## 症状: 「Build Android APK」ワークフローが Actions タブに表示されない

これは **99%が `.github` フォルダのアップロード漏れ** が原因です。

### 原因チェックリスト

#### ✅ 確認1: `.github` フォルダがリポジトリにあるか

GitHubのリポジトリページを開き、ファイル一覧を見てください。

**正しい状態**:
```
📁 .github     ← これが見える必要がある
📁 android
📁 lib
📄 README.md
📄 pubspec.yaml
...
```

**ダメな状態**: `.github` フォルダが**存在しない** → ワークフローが認識されません

### 🚨 `.github` がない場合の3つの解決策

---

### 🟢 解決策1: GitHub Web UI で直接作成（最も確実、推奨）

ブラウザでGitHubリポジトリを開いた状態で:

1. ファイル一覧の上の「**Add file**」→「**Create new file**」をクリック
2. ファイル名欄に **`.github/workflows/build-apk.yml`** と入力
   - ⚠️ 先頭のドット `.` と、スラッシュ `/` を正確に
   - 入力すると自動でフォルダ階層になります
3. エディタに、このZIP内の `.github/workflows/build-apk.yml` の中身を**全部コピペ**
4. 最下部の「**Commit changes**」→「**Commit directly to the main branch**」→「**Commit changes**」
5. もう一度「**Add file**」→「**Create new file**」
6. ファイル名: **`.github/workflows/hello.yml`** で同様にコピペ&コミット
7. リポジトリの「**Actions**」タブを開く → 2つのワークフローが現れているはず！

---

### 🟡 解決策2: ZIPを解凍する際に隠しフォルダを表示する

ブラウザのドラッグ&ドロップでアップロードした場合、**OSが隠しフォルダ（`.` から始まる）を非表示にしているため見落とした可能性**があります。

**Windows の場合:**
- エクスプローラーで解凍したフォルダを開く
- 「表示」タブ → 「隠しファイル」にチェックを入れる
- `.github` フォルダが現れる → これも一緒にアップロード

**Mac の場合:**
- Finder で解凍したフォルダを開く
- `Cmd + Shift + .` を押す（ドット）
- 隠しフォルダが現れる → 一緒にアップロード

その後、GitHub のリポジトリページで「**Add file**」→「**Upload files**」から `.github` フォルダ全体をドラッグ&ドロップ。

---

### 🔵 解決策3: Git コマンドで push

```bash
cd bestpay_app   # 解凍したフォルダ
git init
git add .                   # ← .git は含まないが .github は含まれる
git commit -m "v1.1 with GitHub Actions"
git branch -M main
git remote add origin https://github.com/<あなたのユーザー名>/<リポジトリ名>.git
git push -u origin main
```

`git add .` は隠しフォルダも含めるので、これが最も確実です。

---

## ✅ Actions タブに表示されたら

「**Hello World (動作確認用)**」と「**Build Android APK**」の2つが現れます。

### 動作確認:
- 「Hello World」が緑チェック✅ → `.github/workflows/` は認識されています
- 「Build Android APK」が黄色の丸🟡 → ビルド中（5〜10分待つ）
- 完了後、緑チェック✅になったら成功

### もし動いていない場合の追加確認:

#### ① リポジトリ設定でActionsが有効か
1. リポジトリの「**Settings**」タブ
2. 左メニュー「**Actions**」→「**General**」
3. 「**Actions permissions**」セクション
4. 「**Allow all actions and reusable workflows**」を選択 → 「**Save**」

#### ② 手動でワークフローを実行
1. 「Actions」タブを開く
2. 左サイドバーの「**Build Android APK**」をクリック
3. 右側に「Run workflow」ボタンが現れる → クリック
4. ブランチを選んで「**Run workflow**」をクリック
5. 数秒後にリスト先頭に新しい実行が現れる

---

## 📥 ビルド成功後にAPKをダウンロード

### スマホブラウザで:
1. GitHubの自分のリポジトリ → 「**Actions**」タブ
2. 緑チェック✅の実行をタップ
3. ページ最下部の「**Artifacts**」セクション
4. 「**BestPay-APK**」をタップ → ZIP がダウンロード
5. ZIPを開いて `BestPay.apk` をタップ → インストール

### もっと簡単にしたい場合は Releases 機能:
PCで:
```bash
git tag v1.1.0
git push origin v1.1.0
```

→ Releases ページに `BestPay.apk` が直リンクで現れる → スマホブラウザでタップしてダウンロード一発！

---

## 💬 よくある質問

**Q. Actions が一度も走らない**
→ 解決策1（Web UIで直接作成）を試してください。これで100%動きます。

**Q. ビルドが失敗（赤バツ❌）**
→ Actions タブで実行を開き、エラーログを確認。多くの場合 `android/` の設定問題なので、ワークフローが自動再生成して再試行で成功します。

**Q. Privateリポジトリだとダウンロードできない**
→ スマホからGitHubにログインしている必要があります。あるいはPublicリポジトリにするか、Releases機能を使ってください。

**Q. APKをタップしても「インストールできません」**
→ Android「設定」→「アプリ」→「特別なアクセス」→「不明なアプリのインストール」で使用ブラウザを許可
