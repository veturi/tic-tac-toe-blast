# TIC TAC TOE, BLAST!

9-player simultaneous tic-tac-toe where you pick a color, not a cell.

## How It Works

1. **Join** - 9 players join a lobby, each assigned a random fixed cell (1-9)
2. **Center Picks** - A random center player picks a color publicly (Red or Blue)
3. **Secret Vote** - Other 8 players pick secretly, then countdown and simultaneous reveal
4. **Score** - Points awarded based on completed lines, repeat until someone has a clear lead

## Quick Start

```bash
mix setup
mix phx.server
```

Visit [localhost:4000](http://localhost:4000) to play.

## Scoring Rules

- Count complete lines per color (8 possible: 3 rows, 3 cols, 2 diags)
- **Net ≠ 0**: Winners get +1 per line advantage, losers get -1 each
- **Tie (net = 0)**: Minority color wins (+1 each), majority loses (-1 each)
- **Full Sweep (9-0)**: All scores reset except center keeps theirs
- **Streak Bonus**: +1/+2/+3 for 2/3/4+ consecutive wins

## Win Condition (BLAST Mode)

First player with a **clear lead** after any round wins instantly.

## Features

- Real-time multiplayer via Phoenix LiveView
- AI bots to fill empty slots
- In-game chat
- Dark/light theme
- No account required

## Tech Stack

- Phoenix 1.8 + LiveView
- DaisyUI + TailwindCSS
- Fly.io (deployment)
