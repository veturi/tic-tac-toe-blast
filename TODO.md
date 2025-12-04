# TIC TAC TOE, BLAST! - Implementation Plan

## Phase 1: Static Board UI ✅
**Visible: 3x3 grid with placeholder cells**
- [x] Create `GameLive` LiveView at `/game/:id`
- [x] Build board component (3x3 grid, DaisyUI styled)
- [x] Add color picker buttons (Red/Blue)
- [x] Show player position indicator

**Files:** `lib/tttblast_web/live/game_live.ex`, `router.ex`

---

## Phase 2: Game GenServer ✅
**Visible: Game state in LiveView, state transitions**
- [x] Create `Game` GenServer with state machine
- [x] States: `lobby → center_pick → choosing → countdown → reveal → scoring`
- [x] Registry for game lookup by ID
- [x] Basic start/join/leave API

**Files:** `lib/tttblast/game.ex`, `lib/tttblast/game_supervisor.ex`

---

## Phase 3: Multiplayer Lobby
**Visible: Player list, ready buttons, join with name**
- [ ] Phoenix Presence for player tracking
- [ ] Join form (name input)
- [ ] Player list showing 9 slots + ready state
- [ ] Auto-start when 9 players ready

**Files:** `lib/tttblast_web/presence.ex`, update `game_live.ex`

---

## Phase 4: Cell Assignment & Center Pick
**Visible: Each player sees their assigned cell, center player picks first**
- [ ] Random cell assignment (1-9) on game start
- [ ] Random center selection
- [ ] Center pick UI (public choice)
- [ ] Transition to `choosing` state after center picks

**Files:** Update `game.ex`, `game_live.ex`

---

## Phase 5: Color Picking & Reveal
**Visible: Pick color secretly, countdown, dramatic reveal**
- [ ] Non-center players pick color secretly
- [ ] Countdown timer (3-5 seconds)
- [ ] Simultaneous reveal animation
- [ ] Board shows all colors

**Files:** Update `game.ex`, `game_live.ex`

---

## Phase 6: Scoring & Win Condition
**Visible: Line counting, score update, winner announcement**
- [ ] Count lines per color (8 possible lines)
- [ ] Calculate net score & apply scoring rules
- [ ] Streak bonus tracking
- [ ] BLAST mode: first clear lead wins
- [ ] Game over / next round flow

**Files:** `lib/tttblast/scoring.ex`, update `game.ex`, `game_live.ex`

---

## State Machine Reference
```
lobby → center_pick → choosing → countdown → reveal → scoring → (center_pick | game_over)
```

## Tech Decisions
- **No persistence** (MVP) - games live in memory only
- **Single game room** initially - hardcode game ID
- **PubSub** for real-time updates between players
