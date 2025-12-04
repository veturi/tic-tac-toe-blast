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

## Phase 3: Multiplayer Lobby ✅
**Visible: Player list, ready buttons, join with name**
- [x] Phoenix Presence for player tracking
- [x] Join form (name input)
- [x] Player list showing 9 slots + ready state
- [x] Auto-start when 9 players ready

**Files:** `lib/tttblast_web/presence.ex`, update `game_live.ex`

---

## Phase 4: Cell Assignment & Center Pick ✅
**Visible: Each player sees their assigned cell, center player picks first**
- [x] Random cell assignment (1-9) on game start
- [x] Random center selection
- [x] Center pick UI (public choice)
- [x] Transition to `choosing` state after center picks

**Files:** Update `game.ex`, `game_live.ex`

---

## Phase 5: Color Picking & Reveal ✅
**Visible: Pick color secretly, countdown, dramatic reveal**
- [x] Non-center players pick color secretly
- [x] Countdown timer (3 seconds)
- [x] Simultaneous reveal animation
- [x] Board shows all colors
- [x] Hide other players' picks during choosing (only see your cell + center's)
- [x] Pick count indicator ("5/9 players have picked")

**Files:** Update `game.ex`, `game_live.ex`

---

## Phase 6: Scoring & Win Condition ✅
**Visible: Line counting, score update, winner announcement**
- [x] Count lines per color (8 possible lines)
- [x] Calculate net score & apply scoring rules
- [x] Streak bonus tracking
- [x] BLAST mode: first clear lead wins
- [x] Game over / next round flow

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
