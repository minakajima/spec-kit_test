# spec-kit_test

Spec Kitを使用したPhoenix LiveViewブラウザシューティングゲーム開発プロジェクト

## 概要

このプロジェクトは、GitHubが開発している仕様駆動開発ツール「Spec Kit」を使用して、Phoenix LiveViewで縦型スクロールシューティングゲームを実装したものです。

参考記事: [Spec Kit でシューティングゲームを作る](https://qiita.com/RyoWakabayashi/items/4373e7e9ddc96d9c550f)

## Spec Kitとは

Spec Kitは仕様駆動開発（Spec-Driven Development）のためのツールです。生成AIを「プロジェクトメンバー」として扱い、要件定義→開発計画→詳細設計→実装という流れで開発を進めます。

### 仕様駆動開発の特徴

- 生成AIと一緒に要件定義から詳細設計まで詰めてから実装に取り掛かる
- プロジェクトの目的や規約を理解した上で、確実に指示に従って作業してくれる
- 他のIDEの中で動作する（VSCode、Cursor等）

## セットアップ手順

### 1. Spec Kitのインストール

```powershell
# uvを使用してSpec Kitをインストール
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git

# 環境変数PATHに追加
uv tool update-shell
```

ターミナルを再起動後、以下で確認：

```powershell
specify --help
```

### 2. プロジェクトの初期化

```powershell
# 新規プロジェクトの場合
specify init spec-kit_test

# 既存プロジェクトに適用する場合
specify init .
```

初期化時の選択：
- **AIアシスタント**: `copilot` (GitHub Copilot)
- **スクリプトタイプ**: `ps` (PowerShell) ※Windows環境

## Spec Kit開発ワークフロー

### 基本的な開発フロー

VSCodeでプロジェクトを開き、GitHub Copilot Chatで以下のコマンドを順に実行します：

#### 1. `/speckit.constitution` - プロジェクトの原則を確立

```
/speckit.constitution Phoenix LiveView で縦型のスクロールシューティングゲームを実装したい
```

**成果物**: `.specify/memory/constitution.md`
- プロジェクト全体で守るべき原則を定義
- 技術選定の基準や設計思想を明確化

#### 2. `/speckit.specify` - ベースライン仕様を作成

```
/speckit.specify 開始画面で START ボタンをクリックすると、ゲーム画面に遷移する。
ユーザーはマウスで自機を操作し、クリック中は継続的に弾を発射する。
敵の弾が自機に当たるとゲームオーバー。
自機の弾が敵に当たるとスコアアップ。
最終的なスコアをブラウザ上のストレージに保存する。DBは不要。
```

**成果物**: `specs/001-browser-shooter-game/`
- `spec.md`: 要件定義（Given-When-Then形式）
- `checklists/requirements.md`: 品質チェックリスト

#### 3. `/speckit.plan` - 実装計画を作成

```
/speckit.plan mise で elixir と erlang の最新版をインストールし、
mix phx.new コマンドで Phoenix LiveView プロジェクトを作成（--no-ectoを指定）。
JS と Elixir 間は Hook でデータをやり取りしてリアルタイムに処理してください
```

**成果物**:
- `plan.md`: 技術スタック、アーキテクチャ、プロジェクト構造
- `research.md`: 技術選定の調査結果と根拠
- `data-model.md`: データ構造定義
- `contracts/liveview-events.md`: イベント通信契約
- `quickstart.md`: セットアップガイド

#### 4. `/speckit.tasks` - 実行可能なタスクを生成

```
/speckit.tasks
```

**成果物**: `tasks.md`
- 実装タスクの詳細リスト（T001から順番に）
- 並列実行可能なタスクには`[P]`マーク
- 見積時間も含まれる

#### 5. `/speckit.implement` - 実装を実行

```
/speckit.implement
```

AIが自動的にタスクリストに従って実装を進めます。

### オプションコマンド（品質向上用）

- `/speckit.clarify` - 曖昧な箇所について構造化質問（planの前）
- `/speckit.analyze` - 成果物間の整合性チェック（tasksの後、implementの前）
- `/speckit.checklist` - 品質チェックリスト生成（planの後）

## 実際の開発体験

### 初回実装（Feature 001）

1. **constitution**: Phoenix LiveViewでリアルタイム処理、関数型設計の原則を設定
2. **specify**: 基本的なシューティングゲーム機能を定義
3. **plan**: mise、Phoenix、LiveView Hooksの技術選定
4. **tasks**: 約32時間分のタスクリストを生成
5. **implement**: 基本機能の実装完了

**遭遇した問題**:
- Scoop/mise環境でのPowerShell実行ポリシー問題
- 依存関係の不足（swoosh, finch等）
- 設定ファイルの調整が必要

### 追加機能実装（Feature 002）

難易度向上のため、さらに`/speckit.specify`から再度実施：

```
/speckit.specify よりゲームの難易度を高くしてください。
敵機が弾を発射するようにします。
10秒間隔で、敵の動作、数を増やすようにしてください。
最初は直線的な動きですが、徐々に曲線的で複雑な動きにするものとします。
また、徐々に敵の耐性も上げてください
```

新しいブランチ`002-enemy-difficulty-scaling`が作成され、
同様のフロー（plan → tasks → implement）で実装完了。

## プロジェクト構成

```
spec-kit_test/
├── .github/
│   └── prompts/              # Spec Kit用プロンプト定義
├── .specify/
│   ├── memory/
│   │   └── constitution.md   # プロジェクト原則
│   ├── scripts/              # 自動化スクリプト
│   └── templates/            # テンプレート集
├── specs/
│   ├── 001-browser-shooter-game/  # Feature 1
│   │   ├── spec.md
│   │   ├── plan.md
│   │   ├── tasks.md
│   │   ├── data-model.md
│   │   ├── research.md
│   │   └── contracts/
│   └── 002-enemy-difficulty-scaling/  # Feature 2
└── shooter_game/             # Phoenix LiveViewプロジェクト
    ├── lib/
    │   ├── shooter_game/
    │   │   └── game/        # ゲームロジック
    │   └── shooter_game_web/
    │       └── live/        # LiveViewコンポーネント
    ├── assets/
    │   └── js/
    │       └── hooks/       # クライアントサイドHooks
    └── test/
```

## 技術スタック

- **言語**: Elixir 1.19.1, Erlang/OTP 28
- **フレームワーク**: Phoenix 1.7.21 (LiveView)
- **バージョン管理**: mise
- **フロントエンド**: JavaScript (Canvas API), esbuild, Tailwind CSS
- **ストレージ**: Browser LocalStorage（DBレス）
- **AIアシスタント**: GitHub Copilot (Claude Sonnet 4.5)

## ゲームの起動

```powershell
cd shooter_game
mix deps.get
mix phx.server
```

ブラウザで http://localhost:4000 にアクセス

## 学んだこと

### Spec Kitの利点

1. **体系的なドキュメント生成**: 要件定義から実装計画まで一貫したドキュメントが作成される
2. **整合性の担保**: 各フェーズで前段階のドキュメントを参照し、矛盾のない実装を実現
3. **チーム共有**: 生成されたドキュメントは人間が読んでも理解しやすい
4. **段階的開発**: 小さな単位（Feature単位）で開発を進められる
5. **品質チェック**: constitution、checklist等で品質を担保

### 開発時の注意点

- Windows環境では管理者権限の扱いに注意
- Elixir/Phoenix特有の依存関係を理解する必要がある
- AIの提案を鵜呑みにせず、動作確認とデバッグは必須
- 日本語で応答してほしい場合は明示的に指示する

## セキュリティに関する注意

一部のAIエージェントは認証トークン等を`.github/`フォルダに保存する場合があります。
必要に応じて`.gitignore`に追加することを検討してください。

ただし、Spec Kitの設定を共有したい場合は、慎重に判断する必要があります。

## まとめ

Spec Kitを使用することで、AI駆動の仕様駆動開発を体験できました。
特に、要件定義から実装まで一貫した流れで開発を進められる点が優れています。

生成されたドキュメントは開発プロセスの記録としても価値があり、
プロジェクトに新たに参加するメンバーへのオンボーディング資料としても活用できます。

## 参考リンク

- [Spec Kit GitHub Repository](https://github.com/github/spec-kit)
- [参考記事: Spec Kit でシューティングゲームを作る](https://qiita.com/RyoWakabayashi/items/4373e7e9ddc96d9c550f)
- [Phoenix LiveView](https://github.com/phoenixframework/phoenix_live_view)
- [mise](https://mise.jdx.dev/)

## ライセンス

このプロジェクトはSpec Kitのテンプレートを基に作成されています。
