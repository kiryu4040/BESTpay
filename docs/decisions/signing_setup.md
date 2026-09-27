# APK署名の固定（更新時にアプリを消さなくて済むようにする）

## なぜ必要か
これまでGitHub ActionsがビルドするAPKは、実行のたびに違う鍵で署名されていた。
そのためAndroidは「同じアプリの更新」と認めず、インストールを拒否する。
署名鍵を固定すると、次回以降は上書きインストールできる。

## 手順
1. GitHub の BESTpay リポジトリ → Settings → Secrets and variables → Actions
2. 「New repository secret」で次の4つを登録する（値は配布したファイルを見る）
   - `KEYSTORE_BASE64` : `KEYSTORE_BASE64.txt` の中身（1行の長い文字列）
   - `KEYSTORE_PASSWORD` : `パスワード.txt` の値
   - `KEY_ALIAS` : `bestpay`
   - `KEY_PASSWORD` : `パスワード.txt` の値
3. `.github/workflows/build-apk.yml` を署名対応版に置き換える
4. 何か1つ変更して commit → push すると、署名付きAPKが作られる
5. 一度だけアプリをアンインストールしてから入れる（署名が変わるため）
   → 以降の更新は上書きインストールで済む

## 注意
- `bestpay-release.jks` を失うと、このアプリを更新できなくなる。安全な場所に保管する。
- このファイルとパスワードは他人に渡さない。
