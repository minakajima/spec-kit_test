# 📦 Scoop パッケージマネージャー インストールガイド

## 🚀 Scoop とは

**Scoop** は Windows 用のコマンドラインパッケージマネージャーです。
開発者向けツール（Elixir、Node.js、Git など）を簡単にインストール・管理できます。

### 🎯 Scoop の特徴
- ✅ **管理者権限不要**: 通常ユーザーでインストール・実行可能
- ✅ **クリーンインストール**: システムを汚さない独立したインストール
- ✅ **簡単管理**: コマンド一つでインストール・アップデート・削除
- ✅ **バージョン管理**: 複数バージョンの並行インストール対応

## ⚡ インストール方法

**Scoopのインストールは、PowerShellで2つのコマンドを実行するだけで完了します。管理者権限は不要です。**

### Step 1: 実行ポリシー設定
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Step 2: Scoop インストール
```powershell
irm get.scoop.sh | iex
```

### 🔍 インストール完了確認
```powershell
scoop --version
```

## 📋 詳細手順

### 1. PowerShell を開く
- **Windows 10/11**: `Win + X` → "Windows PowerShell" 選択
- **または**: スタートメニューから "PowerShell" 検索

### 2. 実行ポリシー変更
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```
**説明**: PowerShell でリモートスクリプト実行を許可（現在ユーザーのみ）

### 3. Scoop インストール実行
```powershell
irm get.scoop.sh | iex
```
**説明**: 公式インストールスクリプトをダウンロード・実行

### 4. インストール成功確認
```powershell
scoop --version
```
**期待結果**: Scoop のバージョン情報が表示される

## 🛠️ よくあるトラブルと解決方法

### 問題 1: 実行ポリシーエラー
```
実行ポリシーの変更
...この実行ポリシーによって悪意のあるスクリプトから保護されます。
```
**解決方法**: `Y` (Yes) を入力して続行

### 問題 2: ネットワークエラー
```
インターネット接続に失敗しました
```
**解決方法**: 
- インターネット接続確認
- 企業ネットワークの場合、プロキシ設定確認

### 問題 3: パス認識されない
```
'scoop' は認識されません
```
**解決方法**: PowerShell を再起動してから再実行

## 📦 Scoop 基本コマンド

### パッケージ検索・インストール
```powershell
# パッケージ検索
scoop search <パッケージ名>

# パッケージインストール
scoop install <パッケージ名>

# 複数パッケージ同時インストール
scoop install elixir nodejs git
```

### パッケージ管理
```powershell
# インストール済みパッケージ確認
scoop list

# パッケージ更新
scoop update <パッケージ名>

# 全パッケージ更新
scoop update *

# パッケージ削除
scoop uninstall <パッケージ名>
```

### システム情報
```powershell
# Scoop 情報表示
scoop status

# ヘルプ表示
scoop help
```

## 🎮 ゲーム開発環境構築例

### Phoenix LiveView 開発環境
```powershell
# Scoop インストール後
scoop install elixir nodejs git

# インストール確認
elixir --version
node --version
git --version
```

### 追加開発ツール
```powershell
# エディタ・ユーティリティ
scoop install vscode
scoop install postman
scoop install sqlite

# バージョン管理ツール
scoop install mise
mise install erlang
mise install elixir
```

## 🔧 高度な設定

### バケット追加（パッケージソース拡張）
```powershell
# extras バケット追加（GUIアプリ等）
scoop bucket add extras

# versions バケット追加（旧バージョン）
scoop bucket add versions
```

### 環境変数・パス確認
```powershell
# Scoop インストールディレクトリ
echo $env:SCOOP

# ユーザーアプリインストール先
echo $env:USERPROFILE\scoop\apps
```

## 📞 サポート・参考情報

### 公式リンク
- **公式サイト**: https://scoop.sh/
- **GitHub**: https://github.com/ScoopInstaller/Scoop
- **ドキュメント**: https://github.com/ScoopInstaller/Scoop/wiki

### トラブル時の確認事項
1. **PowerShell バージョン**: `$PSVersionTable.PSVersion`
2. **実行ポリシー確認**: `Get-ExecutionPolicy -Scope CurrentUser`
3. **ネットワーク接続**: `Test-NetConnection -ComputerName google.com -Port 80`

---

## ⚡ クイック実行コマンド

**コピペで即実行（2コマンドのみ）:**

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser; irm get.scoop.sh | iex
scoop install elixir nodejs git
```

**Phoenix LiveView ゲーム開発環境が数分で完了！** 🎮🚀