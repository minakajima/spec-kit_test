# Implementation Plan: ブラウザシューティングゲーム

**Branch**: `001-browser-shooter-game` | **Date**: 2025-10-26 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-browser-shooter-game/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Phoenix LiveViewを用いたリアルタイムブラウザシューティングゲームの実装。マウス操作による自機の移動と射撃、敵との戦闘、スコアシステムをLiveView Hooksで実現。DBは使用せず、スコアはブラウザのローカルストレージに保存。

## Technical Context

**Language/Version**: Elixir (latest stable via mise), Erlang (latest via mise)  
**Primary Dependencies**: Phoenix Framework (LiveView), Phoenix PubSub, esbuild (JS bundler)  
**Storage**: Browser LocalStorage (no database required)  
**Testing**: ExUnit (Elixir標準), Phoenix.LiveViewTest  
**Target Platform**: Modern browsers (Chrome 88+, Firefox 85+, Safari 14+) with WebSocket support  
**Project Type**: Web application (Phoenix LiveView SPA-like)  
**Performance Goals**: 60fps gameplay, <16ms frame time, <50ms server response time  
**Constraints**: <100MB memory per client, real-time mouse tracking, continuous bullet firing during click  
**Scale/Scope**: Single-player game, ~5-10 LiveView components, LocalStorage persistence only

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. リアルタイム最優先
✅ **PASS**: Phoenix LiveView pub/sub使用、60fps目標、16ms以内配信
- LiveView WebSocketでリアルタイム通信
- サーバー側状態管理でクライアント同期なし

### II. 関数型ゲームロジック（非交渉事項）  
✅ **PASS**: Elixirの純粋関数とイミュータブルデータ構造使用
- ゲーム状態遷移は純粋関数で実装
- 副作用はLiveViewとJSフックに分離

### III. LiveViewファーストアーキテクチャ
✅ **PASS**: LiveView + JavaScript Hooks構成
- サーバー：ゲームロジック処理
- クライアント：Canvas描画とマウス入力のみ

### IV. パフォーマンス駆動開発
✅ **PASS**: 60fps、16ms応答時間、100MB制約
- パフォーマンステストとベンチマークを含む

### V. テスト駆動ゲーム開発
✅ **PASS**: ExUnitとPhoenix.LiveViewTest使用計画
- 全ゲーム状態遷移のユニットテスト
- リアルタイム動作の統合テスト

**Phase 1 Design Compliance Re-check**: ✅ ALL GATES PASSED
- 設計されたアーキテクチャは憲法の全原則に準拠
- Phoenix LiveView + GenServer + JavaScript Hooks構成が要件を満たす
- 60fps、16ms応答時間、100MB制約が技術選択で実現可能

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
shooter_game/                          # Phoenix project root
├── lib/
│   ├── shooter_game/
│   │   ├── application.ex             # OTP Application
│   │   └── game/                      # Game logic modules
│   │       ├── state.ex               # Game state management
│   │       ├── player.ex              # Player entity
│   │       ├── enemy.ex               # Enemy entity  
│   │       ├── bullet.ex              # Bullet entity
│   │       └── engine.ex              # Game engine (pure functions)
│   └── shooter_game_web/
│       ├── endpoint.ex                # Phoenix endpoint
│       ├── router.ex                  # Routes
│       ├── live/
│       │   ├── game_live.ex           # Main game LiveView
│       │   ├── start_live.ex          # Start screen LiveView
│       │   └── components/            # LiveView components
│       │       └── score_component.ex
│       └── templates/                 # HTML templates
├── assets/
│   ├── js/
│   │   ├── app.js                     # Main JS entry
│   │   └── hooks/
│   │       ├── game_canvas.js         # Canvas rendering hook
│   │       └── mouse_tracker.js       # Mouse input hook
│   └── css/
│       └── app.css                    # Styling
├── test/
│   ├── shooter_game/
│   │   └── game/                      # Game logic tests
│   ├── shooter_game_web/
│   │   └── live/                      # LiveView tests
│   └── support/
└── config/                            # Phoenix configuration
```

**Structure Decision**: Phoenix LiveView web application with game-specific modules in `lib/shooter_game/game/` for pure game logic and LiveView components in `lib/shooter_game_web/live/` for presentation layer.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
