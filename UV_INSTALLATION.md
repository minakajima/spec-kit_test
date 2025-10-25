# uv (Astral/uv) インストール手順

このドキュメントは Windows（PowerShell）環境で `uv`（Astral/uv）をインストールする手順をまとめたものです。

## 概要
`uv` は Python パッケージ・ツール管理のための高速ツールで、Spec Kit の `specify` CLI インストールで推奨されています。まず `uv` をインストールして PATH に通す必要があります。

## 前提
- Windows（PowerShell）環境
- ネットワークから GitHub Releases や PyPI にアクセスできること
- （オプション）Python 3.11+ を使う場合は既にインストールされていること

---

## 方法 A（推奨）: 公式 PowerShell インストーラを使う
公式リリースに付属の PowerShell インストーラを実行すると、適切なバイナリをダウンロードしてインストールしてくれます。

PowerShell（管理者である必要は通常ありません）で次を実行してください:

```powershell
powershell -ExecutionPolicy Bypass -Command "irm https://github.com/astral-sh/uv/releases/latest/download/uv-installer.ps1 | iex"
```

- 成功すると `uv` 実行ファイルがインストールされ、PATH に追加されるか、案内が表示されます。
- 必要に応じて PowerShell を再起動してください。

## 方法 B: Python（pip）経由でインストール
Python 3.11+ が既にインストールされている場合、pip を使ってユーザー領域へインストールできます。

1. Python のバージョン確認（例）:

```powershell
py -3.11 --version
# または
python --version
```

2. pip でインストール:

```powershell
py -3 -m pip install --upgrade --user uv
# あるいは
python -m pip install --upgrade --user uv
```

3. インストール先の Scripts ディレクトリを PATH に通す（場合による）:
ユーザーインストール時、実行ファイルは通常次のようなフォルダに入ります（Python バージョンによる）:

- `%USERPROFILE%\AppData\Roaming\Python\Python311\Scripts`
- あるいは `%USERPROFILE%\AppData\Local\Programs\Python\Python311\Scripts`

一時的に PowerShell セッションだけ PATH に追加する例:

```powershell
$env:Path += ";$env:USERPROFILE\AppData\Roaming\Python\Python311\Scripts"
```

恒久的に追加する場合は「システム環境変数の編集」から編集してください。

## PATH にパスを追加する（具体例）

例えば `C:\Users\mikio\.local\bin` を PATH に追加する方法は次の通りです。
（ご自身のユーザー名に合わせてパスを置き換えてください）

コマンドプロンプト（cmd）の一時追加:

```cmd
set Path=C:\Users\mikio\.local\bin;%Path%
```

PowerShell の一時追加:

```powershell
$env:Path = "C:\Users\mikio\.local\bin;$env:Path"
```

これらは現在のシェルセッションにのみ有効です。恒久的に追加するには「環境変数の編集（システムのプロパティ）」からユーザー PATH に追記するか、PowerShell でレジストリ/環境変数を編集する手順を行ってください。追加後はシェルを再起動して PATH を再読み込みしてください。

---

## インストール確認
インストール後、次のコマンドで確認します:

```powershell
uv --version
Get-Command uv
where.exe uv
```

`uv --version` がバージョンを返せばインストール成功です。

---

## `specify` CLI のインストール（`uv` が使用可能になった後）
Persistent にインストールする例:

```powershell
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
```

ワンタイムで `specify` を実行する方法:

```powershell
uvx --from git+https://github.com/github/spec-kit.git specify init <PROJECT_NAME>
```

---

## よくある問題と対処
- uv が見つからない（`CommandNotFoundException`）
  - PowerShell を再起動して PATH を再読み込みする。
  - ユーザーレベルで pip インストールした場合は Scripts ディレクトリが PATH に含まれているか確認。
- 権限エラー
  - 管理者権限が必要な場合は管理者 PowerShell で実行するか、ユーザー領域インストール（`--user`）を試す。
- 企業プロキシ・ファイアウォールでダウンロード失敗
  - プロキシ設定を確認する。必要なら一時的に別ネットワークで実行して確認。
- Python バージョンが古い
  - `uv` の一部機能や `specify` が Python 3.11+ を前提としているため、3.11 以上を検討する。

---

## 参考・リンク
- Spec Kit README: https://github.com/github/spec-kit
- uv ドキュメント: https://docs.astral.sh/uv/
- uv Releases (Windows インストーラ含む): https://github.com/astral-sh/uv/releases

---

作業メモ: `uv` をインストールしたら上記の `specify` インストールコマンドを実行して動作確認してください。エラーが出た場合は出力をコピーして共有してください。