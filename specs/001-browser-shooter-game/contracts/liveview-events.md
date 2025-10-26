# LiveView Events Contract

**Date**: 2025-10-26  
**Related**: [data-model.md](../data-model.md)

## Overview

Phoenix LiveView間のイベント通信契約定義。すべてのイベントはクライアント（JavaScript Hooks）とサーバー（LiveView）間でやり取りされる。

---

## Client → Server Events

クライアント側のHooksからサーバー側のLiveViewへ送信されるイベント。

### 1. `mouse_move`

マウスが移動した時にプレイヤーの位置を更新する。

**Payload**:
```javascript
{
  x: number,  // Canvas上のX座標 (0 ~ game_width)
  y: number   // Canvas上のY座標 (0 ~ game_height)  
}
```

**Example**:
```javascript
this.pushEvent("mouse_move", {x: 400, y: 300});
```

**Frequency**: 60Hz (on every mousemove event)
**Validation**: Server側でゲーム境界内に制限

### 2. `mouse_down`

マウスボタンが押された時の射撃開始。

**Payload**:
```javascript
{
  button: number,     // 0=left, 1=middle, 2=right
  timestamp: number   // performance.now() milliseconds
}
```

**Example**:
```javascript  
this.pushEvent("mouse_down", {button: 0, timestamp: performance.now()});
```

**Frequency**: On event only
**Note**: 左ボタン（button: 0）のみ射撃として処理

### 3. `mouse_up`

マウスボタンが離された時の射撃停止。

**Payload**:
```javascript
{
  button: number,     // 0=left, 1=middle, 2=right
  timestamp: number   // performance.now() milliseconds
}
```

**Example**:
```javascript
this.pushEvent("mouse_up", {button: 0, timestamp: performance.now()});
```

### 4. `start_game`

STARTボタンがクリックされた時のゲーム開始。

**Payload**:
```javascript
{}  // Empty payload
```

**Example**:
```javascript
this.pushEvent("start_game", {});
```

### 5. `restart_game`

ゲームオーバー後の再開。

**Payload**:
```javascript
{}  // Empty payload
```

---

## Server → Client Events

サーバー側のLiveViewからクライアント側のHooksへ送信されるイベント。

### 1. `game_state_update`

ゲーム状態の更新を通知。毎フレーム（30Hz）で送信。

**Payload**:
```javascript
{
  player: {
    x: number,
    y: number, 
    health: number,        // 0 or 1
    firing: boolean
  },
  enemies: [
    {
      id: string,          // unique identifier
      x: number,
      y: number,
      type: string,        // "basic" | "curved" | "aggressive" 
      health: number
    }
  ],
  player_bullets: [
    {
      id: string,
      x: number,
      y: number
    }
  ],
  enemy_bullets: [
    {
      id: string, 
      x: number,
      y: number
    }
  ],
  score: number,
  status: string,          // "start" | "playing" | "game_over"
  elapsed_time: number     // milliseconds since game start
}
```

**Example**:
```javascript
// Hook receives this data
this.handleEvent("game_state_update", (payload) => {
  this.renderGameState(payload);
});
```

### 2. `score_update`

スコア更新の通知（敵撃破時）。

**Payload**:
```javascript
{
  score: number,           // new total score
  added_points: number,    // points just earned
  enemy_type: string       // type of enemy destroyed
}
```

### 3. `game_over`

ゲーム終了の通知。

**Payload**:
```javascript
{
  final_score: number,
  high_score: number,      // current high score
  is_new_high_score: boolean,
  stats: {
    enemies_destroyed: number,
    time_survived: number, // milliseconds
    accuracy: number       // percentage (0-100)
  }
}
```

### 4. `local_storage_save`

ローカルストレージ保存指示。

**Payload**:
```javascript
{
  score_data: {
    current_score: number,
    high_score: number, 
    games_played: number,
    total_enemies_destroyed: number,
    last_played: string  // ISO datetime
  }
}
```

**Client Action**: データをLocalStorageに保存
```javascript
localStorage.setItem('shooter_game_scores', JSON.stringify(payload.score_data));
```

---

## Error Handling

### Client → Server Error Cases

**Invalid Coordinates**:
```javascript
// Server response for out-of-bounds mouse coordinates
{
  error: "invalid_coordinates",
  message: "Mouse coordinates outside game area"
}
```

**Game State Mismatch**:
```javascript
// Client tries to fire while game is not in "playing" state
{
  error: "invalid_game_state", 
  message: "Cannot fire while game is not active"
}
```

### Server → Client Error Cases

**Connection Issues**:
```javascript
// Hook should handle disconnection gracefully
this.handleEvent("connection_error", () => {
  this.showConnectionLostMessage();
});
```

---

## Performance Contracts

### Rate Limiting
- `mouse_move`: Max 60Hz
- `mouse_down/up`: No limit (event-based)
- `game_state_update`: Fixed 30Hz from server

### Data Size Limits  
- Max entities per frame:
  - Enemies: 10
  - Player bullets: 25
  - Enemy bullets: 25
- Max payload size: ~2KB per `game_state_update`

### Timeout Handling
- Client must respond to `game_state_update` within 16ms
- Server drops stale mouse events older than 100ms
- Connection timeout: 5 seconds → show reconnect UI

---

## WebSocket LiveView Integration

### Phoenix Channel Configuration
```elixir
# In router.ex
live "/game", ShooterGameWeb.GameLive, :index
live "/", ShooterGameWeb.StartLive, :index
```

### JavaScript Hook Registration
```javascript
// In app.js
import {GameCanvasHook} from "./hooks/game_canvas"
import {MouseTrackerHook} from "./hooks/mouse_tracker" 

let Hooks = {
  GameCanvas: GameCanvasHook,
  MouseTracker: MouseTrackerHook
}

let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})
```

### LiveView Mount Callback
```elixir
# In game_live.ex
def mount(_params, _session, socket) do
  if connected?(socket) do
    # Start game timer
    :timer.send_interval(33, self(), :game_tick) # 30Hz
  end
  
  {:ok, assign(socket, :game_state, initial_game_state())}
end
```