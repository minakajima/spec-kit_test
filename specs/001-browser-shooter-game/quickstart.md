# Quickstart: ブラウザシューティングゲーム

**Date**: 2025-10-26  
**Related**: [plan.md](./plan.md), [data-model.md](./data-model.md)

## Overview

Phoenix LiveViewでシューティングゲームを開発するためのセットアップガイド。ElixirとErlangのインストールから、ローカル開発サーバーの起動まで。

---

## Prerequisites

- Windows 10/11（PowerShell 5.1以降）
- Git（バージョン管理用）
- Modern browser（Chrome 88+、Firefox 85+、Safari 14+、Edge 88+）

---

## Step 1: mise のインストール

miseは複数のプログラミング言語のバージョン管理ツールです。

### Windows (PowerShell)

```powershell
# Scoopを使用してmiseをインストール（推奨）
# Scoopが未インストールの場合、先にインストール
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
irm get.scoop.sh | iex

# miseをインストール
scoop install mise
```

### 代替方法（手動インストール）

```powershell
# GitHubから最新リリースをダウンロード
$version = "v2024.10.7"  # 最新バージョンを確認
$url = "https://github.com/jdx/mise/releases/download/$version/mise-$version-win64.zip"
Invoke-WebRequest $url -OutFile "mise.zip"
Expand-Archive "mise.zip" -DestinationPath "C:\mise"

# パスに追加
$env:PATH += ";C:\mise"
```

### インストール確認

```powershell
mise --version
# 出力例: mise 2024.10.7
```

---

## Step 2: Elixir と Erlang のインストール

### mise経由でインストール

```powershell
# 最新安定版をインストール
mise install erlang@latest
mise install elixir@latest

# プロジェクト用バージョンを設定
mise use erlang@26.1.2
mise use elixir@1.15.7

# インストール確認
elixir --version
# 出力例:
# Erlang/OTP 26 [erts-14.1.1] [source] [64-bit] [smp:8:8] [ds:8:8:10] [async-threads:1] [jit:ns]
# Elixir 1.15.7 (compiled with Erlang/OTP 26)
```

### 環境設定

```powershell
# .tool-versionsファイルを作成（プロジェクトルート）
@"
erlang 26.1.2
elixir 1.15.7
"@ | Out-File -FilePath ".tool-versions" -Encoding utf8
```

---

## Step 3: Phoenix プロジェクトの作成

### Phoenix インストール

```powershell
# Phoenixジェネレータをインストール
mix archive.install hex phx_new

# プロジェクト作成（データベースなし）
mix phx.new shooter_game --no-ecto

# プロジェクトディレクトリに移動
cd shooter_game
```

### 依存関係のインストール

```powershell
# Elixir依存関係
mix deps.get

# Node.js依存関係（フロントエンド）
cd assets
npm install
cd ..
```

---

## Step 4: 開発環境の設定

### 設定ファイルの調整

**config/dev.exs** の調整：
```elixir
config :shooter_game, ShooterGameWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "YOUR_SECRET_KEY_BASE",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]}
  ]
```

### JavaScript設定

**assets/js/app.js** にHooks設定を追加：
```javascript
// Import LiveView hooks
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// Game-specific hooks
let Hooks = {}

// Game Canvas Hook will be added during implementation
Hooks.GameCanvas = {
  mounted() {
    console.log("GameCanvas hook mounted")
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
```

---

## Step 5: ローカル開発サーバーの起動

### サーバー起動

```powershell
# 開発サーバーを起動
mix phx.server

# または、インタラクティブモードで起動
iex -S mix phx.server
```

### ブラウザでアクセス

開発サーバー起動後、ブラウザで以下にアクセス：

**URL**: `http://localhost:4000`

期待される出力：
```
[info] Running ShooterGameWeb.Endpoint with cowboy 2.10.0 at 127.0.0.1:4000 (http)
[info] Access ShooterGameWeb.Endpoint at http://localhost:4000
[watch] build finished, watching for changes...
```

---

## Step 6: 基本的なディレクトリ構成の確認

```
shooter_game/
├── assets/              # フロントエンド资源
│   ├── css/
│   ├── js/
│   └── static/
├── config/              # 設定ファイル
├── lib/
│   ├── shooter_game/    # ゲームロジック（後で追加）
│   └── shooter_game_web/# Web層（LiveView）
│       ├── controllers/
│       ├── live/        # LiveViewモジュール（後で追加）
│       └── templates/
├── priv/               # 静的リソース
└── test/               # テストファイル
```

---

## Development Workflow

### 日常的な開発コマンド

```powershell
# 開発サーバー起動
mix phx.server

# テスト実行
mix test

# テスト（ウォッチモード）
mix test.watch

# 依存関係更新
mix deps.get

# フォーマット確認
mix format --check-formatted

# 静的解析
mix credo
```

### ホットリロード機能

開発サーバー実行中、以下のファイル変更で自動リロード：

- **Elixirファイル** (.ex, .exs): コード変更で自動コンパイル
- **テンプレートファイル** (.heex): 即座にブラウザ更新
- **CSS/JS** ファイル: esbuildで自動ビルド＆ブラウザ更新

---

## Troubleshooting

### よくある問題と解決方法

**1. Port 4000 already in use**
```powershell
# ポート使用プロセス確認
netstat -ano | findstr :4000

# プロセス終了（PID確認後）
taskkill /PID <PID> /F

# または別ポート使用
mix phx.server --port 4001
```

**2. mise not found**
```powershell
# PATH設定確認
$env:PATH

# mise手動パス追加
$env:PATH += ";C:\path\to\mise"
```

**3. Node.js dependencies issue**
```powershell
# Node.jsモジュールクリア＆再インストール
cd assets
Remove-Item node_modules -Recurse -Force
Remove-Item package-lock.json -Force
npm install
cd ..
```

**4. Elixir compilation errors**
```powershell
# 依存関係クリーンアップ
mix deps.clean --all
mix deps.get
mix compile
```

---

## Next Steps

環境セットアップ完了後の次のステップ：

1. **ゲームロジックモジュール作成**: `lib/shooter_game/game/`
2. **LiveViewコンポーネント作成**: `lib/shooter_game_web/live/`  
3. **JavaScript Hooks実装**: `assets/js/hooks/`
4. **Canvas描画機能**: HTML5 Canvas integration
5. **テスト作成**: `test/shooter_game/` and `test/shooter_game_web/`

---

## Performance Tips

### 開発環境の最適化

```powershell
# Elixirコンパイラー並列化
$env:ERL_COMPILER_OPTIONS = "parallel"

# LiveViewデバッグログ有効化
$env:PHX_SERVER = "true"
```

### リソース監視

```powershell
# メモリ使用量確認
Get-Process | Where-Object {$_.ProcessName -eq "beam.smp"} | Select-Object ProcessName,WorkingSet

# CPUリソース確認
Get-Counter "\Process(beam.smp*)\% Processor Time"
```

このクイックスタートガイドに従うことで、Phoenix LiveViewシューティングゲーム開発の基盤環境を構築できます。