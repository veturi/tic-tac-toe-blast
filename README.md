# TIC TAC TOE, BLAST!

9-player simultaneous tic-tac-toe where you pick a color, not a cell.

## How It Works

1. 9 players join a lobby, each assigned a random fixed cell (1-9)
2. A random center player is announced and picks a color publicly
3. Other 8 players pick secretly, then countdown and simultaneous reveal
4. Score calculated based on completed lines, repeat until winner

## Getting Started

```bash
mix setup
mix phx.server
```

Visit [localhost:4000/game/test](http://localhost:4000/game/test) to see the game board.

## Tech Stack

- Phoenix + LiveView
- DaisyUI + TailwindCSS
- Fly.io (deployment target)

## Implementation Status

- [x] **Phase 1:** Static Board UI - 3x3 grid, color picker, player position
- [x] **Phase 2:** Game GenServer with state machine, Registry, PubSub
- [x] **Phase 3:** Multiplayer Lobby - Join form, player list, ready states
- [x] **Phase 4:** Cell Assignment & Center Pick - Public center pick, state transitions
- [ ] **Phase 5:** Color Picking & Reveal
- [ ] **Phase 6:** Scoring & Win Condition

See [TODO.md](TODO.md) for detailed implementation plan.
