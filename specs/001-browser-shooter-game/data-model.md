# Data Model: ブラウザシューティングゲーム

**Date**: 2025-10-26  
**Related**: [plan.md](./plan.md), [research.md](./research.md)

## Overview

Phoenix LiveViewで実装するシューティングゲームの全エンティティとゲーム状態の定義。すべてのデータ構造はElixirの不変データ構造として実装され、純粋関数で変換される。

---

## Core Entities

### 1. GameState
ゲーム全体の状態を保持するルートエンティティ。

```elixir
defmodule ShooterGame.Game.State do
  @enforce_keys [:player, :status]
  defstruct [
    :player,              # %Player{}
    enemies: [],          # [%Enemy{}]
    player_bullets: [],   # [%Bullet{}]
    enemy_bullets: [],    # [%Bullet{}]
    score: 0,             # integer
    high_score: 0,        # integer
    status: :start,       # :start | :playing | :game_over
    game_width: 800,      # integer (pixels)
    game_height: 600,     # integer (pixels)
    last_spawn_time: 0,   # monotonic time
    elapsed_time: 0,      # milliseconds since game start
    time_limit: 180_000   # 3 minutes in milliseconds
  ]
  
  @type status :: :start | :playing | :game_over
  
  @type t :: %__MODULE__{
    player: Player.t(),
    enemies: [Enemy.t()],
    player_bullets: [Bullet.t()],
    enemy_bullets: [Bullet.t()],
    score: non_neg_integer(),
    high_score: non_neg_integer(),
    status: status(),
    game_width: pos_integer(),
    game_height: pos_integer(),
    last_spawn_time: integer(),
    elapsed_time: non_neg_integer(),
    time_limit: pos_integer()
  }
end
```

**Fields**:
- `player`: プレイヤーエンティティ（必須）
- `enemies`: 画面上の全敵リスト
- `player_bullets`: プレイヤーが発射した弾リスト
- `enemy_bullets`: 敵が発射した弾リスト
- `score`: 現在のスコア
- `high_score`: ハイスコア（LocalStorageから読み込み）
- `status`: ゲームの状態（開始画面/プレイ中/ゲームオーバー）
- `game_width/height`: ゲーム画面のサイズ
- `last_spawn_time`: 最後に敵が出現した時刻
- `elapsed_time`: ゲーム開始からの経過時間
- `time_limit`: 制限時間

---

### 2. Player
プレイヤー機エンティティ。

```elixir
defmodule ShooterGame.Game.Player do
  @enforce_keys [:x, :y]
  defstruct [
    :x, :y,               # float coordinates
    health: 1,            # integer (1=alive, 0=dead)
    width: 40,            # integer (pixels)
    height: 40,           # integer (pixels)
    firing: false,        # boolean
    last_shot_time: 0,    # monotonic time
    shot_cooldown: 100    # milliseconds between shots
  ]
  
  @type t :: %__MODULE__{
    x: float(),
    y: float(), 
    health: non_neg_integer(),
    width: pos_integer(),
    height: pos_integer(),
    firing: boolean(),
    last_shot_time: integer(),
    shot_cooldown: pos_integer()
  }
end
```

**Validation Rules**:
- `x`: 0 ≤ x ≤ game_width - width
- `y`: 0 ≤ y ≤ game_height - height  
- `health`: 0 or 1 (boolean-like)
- `shot_cooldown`: minimum 50ms for performance

---

### 3. Enemy  
敵機エンティティ。

```elixir
defmodule ShooterGame.Game.Enemy do
  @enforce_keys [:x, :y, :type]
  defstruct [
    :x, :y, :type,        # coordinates + enemy type
    health: 1,            # integer
    width: 30,            # integer (pixels) 
    height: 30,           # integer (pixels)
    velocity_x: 0.0,      # float (pixels per frame)
    velocity_y: 2.0,      # float (pixels per frame)
    last_shot_time: 0,    # monotonic time
    shot_interval: 1500,  # milliseconds (1.5 seconds per spec)
    curve_amplitude: 0,   # float (for curved movement)
    curve_frequency: 0.1, # float (curve speed)
    spawn_time: 0         # monotonic time when created
  ]
  
  @type enemy_type :: :basic | :curved | :aggressive
  
  @type t :: %__MODULE__{
    x: float(),
    y: float(),
    type: enemy_type(),
    health: pos_integer(),
    width: pos_integer(), 
    height: pos_integer(),
    velocity_x: float(),
    velocity_y: float(),
    last_shot_time: integer(),
    shot_interval: pos_integer(),
    curve_amplitude: float(),
    curve_frequency: float(),
    spawn_time: integer()
  }
end
```

**Enemy Types**:
- `:basic`: 直線移動、定期的弾発射
- `:curved`: 曲線移動（仕様要求）、プレイヤー狙い撃ち  
- `:aggressive`: 高速移動、高頻度発射

---

### 4. Bullet
弾丸エンティティ（プレイヤー・敵共通）。

```elixir
defmodule ShooterGame.Game.Bullet do
  @enforce_keys [:x, :y, :owner, :velocity_x, :velocity_y]
  defstruct [
    :x, :y,               # float coordinates
    :owner,               # :player | :enemy
    :velocity_x,          # float (pixels per frame)  
    :velocity_y,          # float (pixels per frame)
    width: 4,             # integer (pixels)
    height: 8,            # integer (pixels) 
    damage: 1,            # integer
    created_at: 0         # monotonic time
  ]
  
  @type owner :: :player | :enemy
  
  @type t :: %__MODULE__{
    x: float(),
    y: float(),
    owner: owner(),
    velocity_x: float(),
    velocity_y: float(),
    width: pos_integer(),
    height: pos_integer(),
    damage: pos_integer(),
    created_at: integer()
  }
end
```

**Movement Rules**:
- Player bullets: `velocity_y < 0` (upward)
- Enemy bullets: `velocity_y > 0` (downward)  
- Cleanup: Remove when outside game boundaries

---

## State Transitions

### Game Status Flow
```
:start → :playing → :game_over
   ↑                     ↓
   ← ← ← ← ← ← ← ← ← ← ← ←
```

**Transition Triggers**:
- `:start → :playing`: START button clicked
- `:playing → :game_over`: Player health = 0 or time limit reached
- `:game_over → :start`: Restart button clicked

### Entity Lifecycle

**Player**: 
- Created: Game start with initial position
- Updated: Mouse move events
- Destroyed: Health reaches 0

**Enemy**:
- Created: Random spawn timer (every 2-4 seconds)
- Updated: Movement + periodic shooting
- Destroyed: Health = 0 or exits screen bottom

**Bullet**:
- Created: Player fire or enemy fire events
- Updated: Linear movement per frame
- Destroyed: Screen exit or collision

---

## Collision Detection

### Bounding Box Algorithm
```elixir
def collision?(entity1, entity2) do
  x1_left = entity1.x
  x1_right = entity1.x + entity1.width
  y1_top = entity1.y  
  y1_bottom = entity1.y + entity1.height
  
  x2_left = entity2.x
  x2_right = entity2.x + entity2.width
  y2_top = entity2.y
  y2_bottom = entity2.y + entity2.height
  
  x1_left < x2_right and x1_right > x2_left and
  y1_top < y2_bottom and y1_bottom > y2_top
end
```

### Collision Pairs
- Player ↔ Enemy bullets → Game over
- Player bullets ↔ Enemies → Score + enemy destruction  
- Player ↔ Enemies → Game over (direct collision)

---

## Score System

### Score Calculation
```elixir
@score_values %{
  basic: 100,     # basic enemy destroyed
  curved: 150,    # curved enemy destroyed  
  aggressive: 200 # aggressive enemy destroyed
}
```

### Score Persistence (LocalStorage)
```json
{
  "current_score": 1250,
  "high_score": 3400,
  "games_played": 8,
  "total_enemies_destroyed": 45,  
  "last_played": "2025-10-26T15:30:00Z"
}
```

**Storage Operations**:
- Read on game start (initialize high_score)
- Write on game over (update high_score if exceeded)
- Clear on explicit user request (reset progress)

---

## Performance Considerations

### Memory Management
- **Entity Pools**: Pre-allocate bullet objects to reduce GC
- **Cleanup**: Remove off-screen entities immediately
- **State Size**: Limit max concurrent entities (enemies: 10, bullets: 50)

### Update Frequency
- **Game Logic**: 30Hz (server-side)
- **Rendering**: 60Hz (client-side interpolation)
- **Network**: Delta updates only

### Validation
- All coordinate updates validate screen boundaries
- Health values clamped to valid ranges
- Time-based operations use monotonic time for consistency