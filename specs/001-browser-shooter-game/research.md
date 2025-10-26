# Research: ブラウザシューティングゲーム

**Date**: 2025-10-26  
**Related**: [plan.md](./plan.md), [spec.md](./spec.md)

## Overview

Phoenix LiveViewを用いたリアルタイムシューティングゲームの技術的実現方法について調査。特にJavaScript-Elixir間のリアルタイム通信、ゲームループ実装、レンダリング方式、衝突判定の最適な実装方法を決定する。

---

## Research Task 1: Canvas vs SVG Rendering

### Decision
**Canvas APIを使用**

### Rationale

1. **パフォーマンス**: 60fpsを維持するには、多数のゲームエンティティ（自機、敵複数、弾複数）を毎フレーム再描画する必要がある。CanvasはピクセルベースのImmediate modeレンダリングで、DOM操作が不要なため高速
2. **ゲーム向き**: Canvas APIはゲーム開発の標準的な選択肢で、`requestAnimationFrame`との統合が容易
3. **LiveView統合**: Canvasは単一のDOM要素として扱えるため、LiveViewのdiff計算に影響しない。ゲーム状態の更新とCanvas描画を分離できる

### Alternatives Considered

- **SVG**: DOM要素として各エンティティを表現。LiveViewのコンポーネントモデルと相性が良いが、多数の要素を扱う際のパフォーマンスが劣る。60fps維持が困難
- **HTML+CSS Transforms**: 同様にDOM要素だがSVGより軽量。ただしゲームの複雑なビジュアルエフェクトに制限あり

---

## Research Task 2: Real-time Communication Pattern

### Decision
**Phoenix LiveView + JavaScript Hooks**

### Rationale

1. **双方向通信**: LiveViewのWebSocketで自動的な双方向通信が確立される。マウスイベント（クライアント→サーバー）とゲーム状態更新（サーバー→クライアント）を効率的に処理
2. **状態管理**: サーバー側でゲーム状態を一元管理し、クライアントは描画のみに専念。憲法の「サーバー唯一の情報源」原則に準拠
3. **低レイテンシ**: WebSocketの持続的接続で、HTTPリクエスト/レスポンスのオーバーヘッドなし

### Alternatives Considered

- **REST API + ポーリング**: シンプルだが、リアルタイム性に劣る。60fps要件を満たすには過度のリクエスト頻度が必要
- **WebSocket直接使用**: より細かい制御は可能だが、LiveViewの自動状態管理機能を活用できない

---

## Research Task 3: Game Loop Implementation

### Decision
**サーバー側GenServer + クライアント側requestAnimationFrame**

### Rationale

1. **ハイブリッドアプローチ**: ゲームロジック（敵生成、衝突判定、状態遷移）はサーバー側GenServerで、描画はクライアント側requestAnimationFrameで実行
2. **パフォーマンス最適化**: サーバー側は30Hz程度でロジック処理、クライアント側は60Hzで描画。ネットワーク帯域を節約しつつ滑らかな描画を実現
3. **状態同期**: GenServerがゲーム状態を管理し、変更時にLiveViewでクライアントに配信。クライアントは補間処理で滑らかな動きを表現

### Alternatives Considered

- **フル60Hz同期**: サーバーとクライアント両方を60Hzで同期。理想的だがネットワーク負荷とサーバー負荷が高い
- **クライアント中心**: クライアント側でゲームロジックを実行し、サーバーは結果のみ受信。憲法の原則に反する

---

## Research Task 4: Collision Detection Strategy

### Decision
**Bounding Box（矩形衝突判定）**

### Rationale

1. **シンプルさ**: 各エンティティを矩形として扱い、重複判定で衝突検出。実装が簡単で計算量が少ない
2. **パフォーマンス**: O(n²)だが、想定するエンティティ数（プレイヤー1、敵5-10、弾10-20）では十分高速
3. **精度**: シューティングゲームの要求精度には十分。より高精度が必要なら円形衝突判定に後で変更可能

### Alternatives Considered

- **Circle Collision**: より正確だが計算量がわずかに増加。当初は不要
- **Pixel Perfect**: 最高精度だが計算負荷が高い。リアルタイム要件に適さない

---

## Research Task 5: Score Persistence Strategy

### Decision
**LocalStorage + JSON形式**

### Rationale

1. **シンプルさ**: ブラウザのLocalStorageに直接保存。データベース不要でインフラ負荷なし
2. **クロスセッション対応**: ブラウザを閉じても数据は保持される
3. **JSON互換性**: Elixirの構造体をJSONでシリアライズし、JavaScript側で簡単に処理可能

### Data Structure
```json
{
  "highScore": 12500,
  "lastScore": 8900,
  "gamesPlayed": 15,
  "lastPlayed": "2025-10-26T10:30:00Z"
}
```

### Alternatives Considered

- **Cookie**: データサイズ制限あり、HTTPリクエスト毎に送信されるため非効率
- **SessionStorage**: ブラウザタブを閉じるとデータが失われる
- **IndexedDB**: 過剰に複雑、シンプルなスコア保存には不要

---

## Technical Integration Points

### LiveView ↔ JavaScript Hook Communication

**イベントフロー**:
1. マウス移動 → Hook → `pushEvent("mouse_move", {x, y})` → LiveView
2. LiveView → ゲーム状態更新 → `push_event("game_state", state)` → Hook
3. Hook → Canvas描画更新

**データ形式**:
```javascript
// Client to Server
{
  type: "mouse_move" | "mouse_down" | "mouse_up",
  x: number,
  y: number,
  timestamp: number
}

// Server to Client  
{
  player: {x: number, y: number, health: number},
  enemies: [{x, y, health, type}],
  bullets: [{x, y, type, owner}],
  score: number,
  gameState: "playing" | "game_over" | "start"
}
```

---

## Performance Considerations

### Target Metrics
- **Frame Rate**: 60fps描画（クライアント）
- **Game Logic**: 30Hz状態更新（サーバー）
- **Network**: <50ms RTT
- **Memory**: <100MB per client session

### Optimization Strategies
1. **Object Pooling**: 弾丸オブジェクトの再利用でGC負荷軽減
2. **Spatial Partitioning**: 衝突判定の計算量削減（必要に応じて）
3. **Delta Compression**: 変更のある状態のみ配信
4. **Client-side Interpolation**: サーバー状態間の補間で滑らかな動き