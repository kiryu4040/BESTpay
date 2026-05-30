# 📲 BestPay APK 入手ガイド v1.1（スマホで使う）

このガイドは「**GitHub経由でAPKをダウンロードしてスマホで使う**」最短ルートを示します。

## 🎯 ゴール
スマホでこのAPKをタップしてインストール → ホーム画面に追加 → オフラインで使う

## 🛠 必要なもの
- パソコン（最初の1回だけ）
- GitHubアカウント（無料）
- Androidスマートフォン (Android 8.0以上)

---

## ⚠️ 最重要ポイント: `.github` フォルダ問題

v1.0ユーザーから「**Actions が走らない**」報告が多発しました。
原因は**ほぼ100%、`.github` フォルダがアップロードされていない**ことです。

`.github` は隠しフォルダ（`.` から始まる）なので、PCで隠しファイル表示OFFのままだと**フォルダの存在自体に気付けません**。

v1.1ではこの問題を確実に回避する手順を案内します。

---

## ステップ1: GitHubアカウントを作成（5分）

1. https://github.com/signup にアクセス
2. メールアドレス、パスワード、ユーザー名を入力
3. メールで届く確認コードを入力

---

## ステップ2: リポジトリを作成（1分）

1. ログイン後、画面右上の「**+**」マークをクリック
2. 「**New repository**」を選択
3. **Repository name**: `bestpay` などお好きな名前
4. **Public** か **Private** どちらでも可
5. 「**Add a README file**」のチェックは**外す** ← 重要
6. 「**Create repository**」をクリック

---

## ステップ3: ソースコードをアップロード

### 🌟 推奨方法: ハイブリッド方式

ZIPファイルからの普通のアップロードと、Web UIでの.github作成を組み合わせます。

#### 3-A. 通常ファイルをアップロード

1. ZIPを解凍してできた `bestpay_app/` フォルダを開く
2. 「lib」「android」「pubspec.yaml」「README.md」など、**見えているもの全部**を選択
3. 「Add file」→「Upload files」をクリック
4. 選択したファイル/フォルダをドラッグ&ドロップ
5. 一番下の「**Commit changes**」をクリック

#### 3-B. `.github/workflows/` を Web UI で作成 (★重要)

`.github` は隠しフォルダなので、ここで**手動で作ります**。

##### build-apk.yml を作成:

1. リポジトリページで「**Add file**」→「**Create new file**」をクリック
2. ファイル名欄に正確に入力:
   ```
   .github/workflows/build-apk.yml
   ```
   → 入力するとスラッシュごとに自動でフォルダ階層になります
3. エディタにZIP内の `.github/workflows/build-apk.yml` の中身を**全部コピペ**
4. 一番下の「**Commit changes**」→「**Commit directly to the main branch**」→「**Commit changes**」

##### hello.yml を作成（動作確認用）:

5. もう一度「**Add file**」→「**Create new file**」
6. ファイル名: `.github/workflows/hello.yml`
7. ZIP内 `.github/workflows/hello.yml` の中身をコピペ
8. 「**Commit changes**」

#### ✅ 確認ポイント

リポジトリページ上で**`.github` フォルダが見える**ことを確認してください:

```
📁 .github       ← これが見える ✅
📁 android
📁 lib
📄 README.md
📄 pubspec.yaml
...
```

---

### 🅱 もう一つの方法: git コマンド（PCにgitがある場合）

```bash
cd bestpay_app   # 解凍したフォルダ
git init
git add .                              # 隠しフォルダも自動で含まれる
git commit -m "Initial commit v1.1"
git branch -M main
git remote add origin https://github.com/<ユーザー名>/<リポジトリ名>.git
git push -u origin main
```

`git add .` は隠しフォルダ含めて全部追加するので、**確実に `.github` も入ります**。

---

## ステップ4: Actions が自動実行されるのを確認

1. リポジトリページ上部の「**Actions**」タブをクリック
2. **2つのワークフロー**が表示される:
   - **Hello World (動作確認用)** ← まずこれが緑になればOK
   - **Build Android APK** ← 本番のAPKビルド
3. Hello World が **5秒で緑チェック** ✅ になる
4. Build Android APK は **5〜10分** ほどかかる
5. 両方緑になれば成功！

### もし Actions タブにワークフローが出ない場合
→ `.github/workflows/` のアップロードが失敗しています。
→ **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** を参照してください。

---

## ステップ5: スマホでAPKをダウンロード

### スマホのブラウザ（Chrome、Safari等）で:

1. GitHubにログイン → 自分のリポジトリを開く
2. 「**Actions**」タブをタップ
3. **Build Android APK** の **成功した実行（緑チェック✅）** をタップ
4. ページ最下部までスクロール → 「**Artifacts**」セクション
5. 「**BestPay-APK**」をタップ → ZIPファイルがダウンロードされる

### スマホのファイルアプリで:

6. ダウンロードフォルダを開く → `BestPay-APK.zip` をタップ
7. ZIPを解凍 → `BestPay.apk` が出てくる
8. `BestPay.apk` をタップ
9. 「**この提供元のアプリのインストールを許可**」を有効にする
10. 「**インストール**」をタップ

### 🎉 完了！

ホーム画面に **BestPay** アイコンが追加されます。

---

## 💡 もっと簡単にしたい: Releases機能

タグを付けてpushすると、APKがGitHubのダウンロードページに**直リンク**で表示されます。

```bash
git tag v1.1.0
git push origin v1.1.0
```

→ リポジトリページ右側の「**Releases**」セクションに **v1.1.0** が表示され、`BestPay.apk` が直リンクで載ります。

スマホブラウザでそのリンクをタップすれば、**ワンタップでAPKダウンロード**できます！

---

## ❓ よくある問題と解決

詳細は **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** を参照してください。

| 症状 | 主な原因 | 解決 |
|---|---|---|
| Actions タブが空 | `.github` 未アップロード | Web UI で直接作成 |
| ビルド失敗 (赤バツ❌) | android/設定問題 | 再実行で自動修復 |
| Artifacts ダウンロード不可 | GitHubログインしてない | スマホでログイン |
| アプリがインストールできない | 不明アプリ許可OFF | 設定で許可 |

---

## 📝 アプリを更新したいとき

1. ローカルで `lib/` 内のソースを編集
2. GitHubに再push
3. Actions が自動で新APK生成
4. スマホで再ダウンロード→再インストール（**既存データは保持されます**）
