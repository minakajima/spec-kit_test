---
description: "Implementation tasks for browser shooter game"
---

# Tasks: ブラウザシューティングゲーム

**Input**: Design documents from `/specs/001-browser-shooter-game/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/liveview-events.md

**Tests**: Test tasks are included per TDD approach specified in constitution.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- Project root: `shooter_game/`
- Game logic: `shooter_game/lib/shooter_game/game/`
- LiveView: `shooter_game/lib/shooter_game_web/live/`
- JavaScript Hooks: `shooter_game/assets/js/hooks/`
- Tests: `shooter_game/test/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic Phoenix LiveView structure

- [ ] T001 Verify mise installation and install Elixir/Erlang per quickstart.md
- [ ] T002 Create Phoenix project with `mix phx.new shooter_game --no-ecto`
- [x] T003 [P] Create directory structure: lib/shooter_game/game, lib/shooter_game_web/live/components, assets/js/hooks
- [ ] T004 [P] Configure PubSub in shooter_game/lib/shooter_game/application.ex
- [ ] T005 [P] Setup esbuild configuration in shooter_game/config/config.exs for JavaScript bundling
- [x] T006 [P] Add Canvas CSS styles in shooter_game/assets/css/app.css
- [ ] T007 Verify development server starts with `mix phx.server` and loads on http://localhost:4000

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core game infrastructure that MUST be complete before ANY user story

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T008 [P] Create GameState struct in shooter_game/lib/shooter_game/game/state.ex per data model
- [ ] T009 [P] Create Player struct in shooter_game/lib/shooter_game/game/player.ex per data model  
- [ ] T010 [P] Create Enemy struct in shooter_game/lib/shooter_game/game/enemy.ex per data model
- [ ] T011 [P] Create Bullet struct in shooter_game/lib/shooter_game/game/bullet.ex per data model
- [ ] T012 [P] Implement collision detection module in shooter_game/lib/shooter_game/game/collision.ex
- [ ] T013 [P] Create GameEngine pure functions in shooter_game/lib/shooter_game/game/engine.ex
- [ ] T014 Setup base LiveView layout in shooter_game/lib/shooter_game_web/templates/layout/live.html.heex
- [ ] T015 [P] Configure JavaScript Hooks structure in shooter_game/assets/js/app.js per contracts
- [ ] T016 [P] Create base test helpers in shooter_game/test/support/game_helpers.ex

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - ゲーム開始とプレイ (Priority: P1) 🎯 MVP

**Goal**: ユーザーがSTART画面からゲームを開始し、マウスで自機を操作して弾を発射できる

**Independent Test**: START画面→ゲーム画面遷移、マウス移動による自機制御、クリック射撃をテスト可能

### Tests for User Story 1

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T017 [P] [US1] LiveView mount test for StartLive in shooter_game/test/shooter_game_web/live/start_live_test.exs
- [ ] T018 [P] [US1] LiveView mount test for GameLive in shooter_game/test/shooter_game_web/live/game_live_test.exs  
- [ ] T019 [P] [US1] Player movement test in shooter_game/test/shooter_game/game/player_test.exs
- [ ] T020 [P] [US1] Bullet creation test in shooter_game/test/shooter_game/game/bullet_test.exs
- [ ] T021 [P] [US1] GameEngine state transition test in shooter_game/test/shooter_game/game/engine_test.exs

### Implementation for User Story 1

- [ ] T022 [P] [US1] Create StartLive module in shooter_game/lib/shooter_game_web/live/start_live.ex
- [ ] T023 [P] [US1] Create GameLive module in shooter_game/lib/shooter_game_web/live/game_live.ex
- [ ] T024 [P] [US1] Create start screen template in shooter_game/lib/shooter_game_web/live/start_live.html.heex
- [ ] T025 [P] [US1] Create game screen template in shooter_game/lib/shooter_game_web/live/game_live.html.heex
- [ ] T026 [US1] Implement player movement functions in GameEngine per data model
- [ ] T027 [US1] Implement bullet firing logic in GameEngine per data model
- [ ] T028 [US1] Create GameCanvas JavaScript Hook in shooter_game/assets/js/hooks/game_canvas.js
- [ ] T029 [US1] Create MouseTracker JavaScript Hook in shooter_game/assets/js/hooks/mouse_tracker.js
- [ ] T030 [US1] Implement Canvas rendering for player and bullets in GameCanvas Hook
- [ ] T031 [US1] Wire up LiveView event handlers for mouse_move, mouse_down, mouse_up per contracts
- [ ] T032 [US1] Add game loop GenServer in shooter_game/lib/shooter_game/game/server.ex for 30Hz updates
- [ ] T033 [US1] Implement start_game event handler and state transitions
- [ ] T034 [US1] Add route configuration in shooter_game/lib/shooter_game_web/router.ex

**Checkpoint**: At this point, User Story 1 should be fully functional - basic playable game with mouse controls

---

## Phase 4: User Story 2 - 戦闘とゲームオーバー (Priority: P2)

**Goal**: 敵機出現、敵弾発射、衝突判定によるゲームオーバー機能

**Independent Test**: 敵機出現、敵弾による衝突、ゲームオーバー画面表示をテスト可能

### Tests for User Story 2

- [ ] T035 [P] [US2] Enemy spawning test in shooter_game/test/shooter_game/game/enemy_test.exs
- [ ] T036 [P] [US2] Enemy bullet firing test in shooter_game/test/shooter_game/game/enemy_test.exs
- [ ] T037 [P] [US2] Collision detection test in shooter_game/test/shooter_game/game/collision_test.exs
- [ ] T038 [P] [US2] Game over state transition test in shooter_game/test/shooter_game/game/engine_test.exs

### Implementation for User Story 2

- [ ] T039 [P] [US2] Implement enemy spawning logic in GameEngine per data model (curved movement pattern)
- [ ] T040 [P] [US2] Implement enemy bullet firing (1.5 second intervals, player-directed) per specification
- [ ] T041 [P] [US2] Add enemy update functions (movement + shooting) in GameEngine
- [ ] T042 [US2] Integrate collision detection into game loop per collision.ex module
- [ ] T043 [US2] Implement game over state transition when player hit
- [ ] T044 [US2] Create GameOver LiveView component in shooter_game/lib/shooter_game_web/live/components/game_over_component.ex
- [ ] T045 [US2] Add Canvas rendering for enemies and enemy bullets in GameCanvas Hook
- [ ] T046 [US2] Implement enemy AI movement patterns (curved motion per research.md)
- [ ] T047 [US2] Add enemy cleanup logic (off-screen removal)
- [ ] T048 [US2] Wire up game over event handling and UI display
- [ ] T049 [US2] Add restart functionality back to start screen

**Checkpoint**: Full combat system functional - enemies appear, shoot, and can destroy player

---

## Phase 5: User Story 3 - スコアシステムとデータ保存 (Priority: P3)

**Goal**: 敵撃破によるスコア加算とローカルストレージへのスコア永続化

**Independent Test**: 敵撃破でスコア加算、ゲーム終了時の保存、ハイスコア表示をテスト可能

### Tests for User Story 3

- [ ] T050 [P] [US3] Score calculation test in shooter_game/test/shooter_game/game/engine_test.exs
- [ ] T051 [P] [US3] LocalStorage integration test in shooter_game/test/shooter_game_web/live/game_live_test.exs
- [ ] T052 [P] [US3] High score persistence test (integration) 

### Implementation for User Story 3

- [ ] T053 [P] [US3] Implement player bullet vs enemy collision detection
- [ ] T054 [P] [US3] Add score calculation logic in GameEngine per data model (100/150/200 points)
- [ ] T055 [P] [US3] Create ScoreComponent LiveView component in shooter_game/lib/shooter_game_web/live/components/score_component.ex
- [ ] T056 [US3] Add enemy destruction logic and score updates
- [ ] T057 [US3] Implement LocalStorage save/load in GameCanvas Hook per contracts
- [ ] T058 [US3] Add high score tracking and comparison logic
- [ ] T059 [US3] Update game over screen to show final and high scores
- [ ] T060 [US3] Add score display during gameplay (real-time updates)
- [ ] T061 [US3] Implement score persistence on game over per LocalStorage contract
- [ ] T062 [US3] Add high score display on start screen

**Checkpoint**: Complete scoring system with persistent high scores

---

## Phase 6: Polish & Performance Optimization

**Purpose**: Performance tuning, error handling, and user experience improvements

- [ ] T063 [P] Add error boundaries and graceful failure handling
- [ ] T064 [P] Implement performance monitoring and fps counter
- [ ] T065 [P] Add sound effects hooks (optional enhancement)
- [ ] T066 [P] Optimize Canvas rendering for 60fps target per performance goals
- [ ] T067 [P] Add responsive design for different screen sizes
- [ ] T068 [P] Implement proper cleanup on LiveView unmount
- [ ] T069 Add comprehensive integration tests for full game flow
- [ ] T070 Add browser compatibility testing
- [ ] T071 Performance benchmark to verify <16ms server response times
- [ ] T072 Memory usage verification (<100MB per session)
- [ ] T073 Add production deployment configuration

---

## Dependencies & Execution Order

### Critical Path (Sequential Dependencies)

1. **Phase 1 → Phase 2**: Setup must complete before foundational work
2. **Phase 2 → Phase 3**: Core game structures must exist before user stories
3. **US1 → US2**: Basic game mechanics must work before adding enemies
4. **US2 → US3**: Combat system must exist before scoring system

### Parallel Opportunities by Phase

**Phase 2 (Foundational)**:
- T008-T013: All data structures can be built in parallel
- T014-T016: UI and test infrastructure can be built in parallel

**Phase 3 (US1)**:  
- T017-T021: All tests can be written in parallel
- T022-T025: All LiveView templates can be built in parallel
- T028-T029: JavaScript Hooks can be developed in parallel
- After T027: T030-T034 can run in parallel (wiring up the components)

**Phase 4 (US2)**:
- T035-T038: All tests in parallel  
- T039-T041: Enemy logic can be developed in parallel
- T044-T047: UI components and rendering in parallel

**Phase 5 (US3)**:
- T050-T052: All tests in parallel
- T053-T055: Core scoring logic in parallel
- T057-T062: UI and persistence features in parallel

**Phase 6 (Polish)**:
- T063-T068: All polish tasks can run in parallel
- T069-T073: All verification tasks can run in parallel

---

## Implementation Strategy

### MVP Scope (Phase 1-3)
**Estimated Time**: 8-12 hours
- Basic playable game with mouse controls
- Player movement and shooting
- Simple start screen
- **Deliverable**: Demonstrable core game mechanics

### Full Feature Scope (Phase 1-5) 
**Estimated Time**: 16-20 hours  
- Complete game with enemies and scoring
- Persistent high scores
- Full game loop (start → play → game over → restart)
- **Deliverable**: Complete shooting game experience

### Production Ready (Phase 1-6)
**Estimated Time**: 24-30 hours
- Performance optimized
- Error handling
- Cross-browser compatibility
- **Deliverable**: Production deployment ready

### Parallel Development Approach

1. **Setup (2-3 developers)**: Phase 1 & 2 in parallel
2. **Core Game (2-3 developers)**: Phase 3 tasks split by component (LiveView vs JavaScript vs Game Logic)  
3. **Advanced Features (2 developers)**: Phase 4 & 5 can start once Phase 3 core is stable
4. **Quality Assurance (1 developer)**: Phase 6 polish while others finish implementation

**Total Estimated Tasks**: 73 tasks
**Parallel Opportunities**: ~40% of tasks can run in parallel within phases
**Critical Dependencies**: 4 major sequential gates (Setup → Foundation → US1 → US2+US3)