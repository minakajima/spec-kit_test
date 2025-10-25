# specify CLI インストール手順

このドキュメントは Windows（PowerShell）環境を想定して、`specify`（Spec Kit の CLI）のインストールと確認手順、よくあるトラブルの対処法をまとめたものです。

---

## 前提
- `uv`（Astral/uv）がインストール済みであること（`uv --version` で確認）
- `git` がインストール済みで PATH に含まれていること（`git --version` で確認）
- ネットワークから GitHub にアクセスできること（プロキシ等の制限がないこと）

> 注: `uv` は Spec Kit README の推奨ツールです。`uv` が無い場合はまず `UV_INSTALLATION.md` の手順に従ってください。

---

## 方法 A — 永続的にインストール（推奨）
PowerShell で次を実行します:

```powershell
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
```

期待される出力の例:
- 依存解決のメッセージ
- Installed X executable: specify

成功後、`specify` は PATH に入るか、もしくは uv の管理下で実行可能になります。

### アップグレード
最新版に更新する場合:

```powershell
uv tool install specify-cli --force --from git+https://github.com/github/spec-kit.git
```

### アンインストール

```powershell
uv tool uninstall specify-cli
# または uv が管理する名前が differ する場合は uv tool list を確認して正しい名前を使ってください
```

---

## 方法 B — ワンタイム実行（インストールせず試す）
ローカルにインストールせずにコマンドを一時実行するには `uvx` を使います:

```powershell
uvx --from git+https://github.com/github/spec-kit.git specify init <PROJECT_NAME> --ai copilot --script ps
```

この方法はインストール不要で試せますが、毎回ダウンロードが走るため繰り返し使うユースケースには不向きです。

---

## インストール確認
1. `where.exe specify` がパスを返すか確認

```powershell
where.exe specify
```

2. バージョン確認

```powershell
specify --version
```

3. uv の管理下ツール一覧を確認

```powershell
uv tool list
```

上記で `specify` が見つかればインストール成功です。

---

## `specify` の基本的な使い方
- 環境チェック

```powershell
specify check
```

- プロジェクトを初期化（PowerShell スクリプトを生成）

```powershell
specify init my-project --ai copilot --script ps
# カレントディレクトリに初期化する場合
specify init . --ai copilot --script ps
```

---

## よくあるトラブルと対処

1. 「specify が見つからない」
   - 対処:
     - `where.exe specify` が空の場合はインストールされていないか PATH に入っていません。`uv tool install ...` を再実行してログを確認してください。
     - ユーザー領域にインストールされているが PATH にない場合は `%USERPROFILE%\\.local\\bin` や `AppData\\Roaming\\Python\\<version>\\Scripts` を PATH に追加し、PowerShell を再起動してください。

2. Git のクローン失敗 / 認証エラー
   - 対処:
     - `git --version` を確認し、社内プロキシやファイアウォールがある場合はプロキシ経由の設定が必要です。エラー全文を貼ってください。

3. TLS/SSL エラー
   - 対処:
     - 企業の SSL 透過や自己署名証明書が原因のことがあります。セキュリティポリシーに基づきプロキシ/証明書の設定を行ってください。急場しのぎで `--skip-tls` のような回避を使わない方が安全です（`specify init` にあるフラグは README を参照）。詳細エラーを共有してください。

4. パーミッション／権限エラー
   - 対処:
     - 管理者権限の PowerShell を試す、またはユーザー領域インストール（`--user` 相当）を使う。

5. uv のインストール自体に問題がある
   - 対処:
     - `uv --version`、`uv tool list` の出力を貼ってください。uv のログで解決策を判断します。

---

## 追加デバッグコマンド（出力を共有してください）
- `uv --version`
- `uv tool list`
- `where.exe specify`
- `Get-Command specify`
- `git --version`
- `specify --version`（存在する場合）
- `specify init . --ai copilot --script ps` を実行したときのエラー全文（発生したら）

---

## 参考・リンク
- Spec Kit README: https://github.com/github/spec-kit
- Spec Kit (GitHub Releases): https://github.com/github/spec-kit/releases
- uv ドキュメント: https://docs.astral.sh/uv/

---

問題が出たら、上記のデバッグコマンドの出力をそのまま貼ってください。次の具体的な対処をすぐに案内します。
