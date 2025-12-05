# TIC TAC TOE, BLAST! — PRD v1.0

## ONE-LINER

9-player simultaneous tic-tac-toe where you pick a color, not a cell.

---

## CORE LOOP

1. 9 players join lobby → each assigned random fixed cell
2. Random center announced → center picks color publicly
3. Other 8 pick secretly → countdown → simultaneous reveal
4. Score calculated → repeat until winner

---

## SCORING

```
1. Count complete lines per color (8 possible: 3 rows, 3 cols, 2 diags)
2. Net = RedLines - BlueLines
3. If net ≠ 0: winners +1 per net line, losers -1 each
4. If net = 0: minority color +1, majority -1
5. Full sweep (9-0): all scores reset except center keeps theirs
```

**Streak bonus:** +1 / +2 / +3 for 2 / 3 / 4+ consecutive wins

---

## WIN CONDITIONS

- **BLAST:** First player with clear lead after any round

---

## TECH

Phoenix + LiveView + DaisyUI + TailwindCSS + Fly.io

- Game room = GenServer holding state
- Players connect via Phoenix LiveView
- Phoenix Presence for lobby/ready state
- PubSub for real-time broadcasts
- State machine: `lobby → center_pick → choosing → countdown → reveal → scoring → repeat`

---

## DATA MODEL

```
Game: id, round, state, center_player_id, cells[], players{}, round_result{}
Player: id, name, cell (1-9), pick (:red/:blue/nil), score, streak, ready, is_bot
Cell: position (1-9), player_id, color (:red/:blue/nil)
```

---

## IMPLEMENTED FEATURES

### Core MVP (Complete)
- [x] Dynamic game rooms (any ID creates a room)
- [x] Join with name
- [x] 9-player lobby with ready states
- [x] Random cell + center assignment
- [x] Center pick → others pick → reveal flow
- [x] Scoring logic with all rules
- [x] BLAST mode win condition
- [x] Streak bonus tracking
- [x] Full UI showing board + scores + round results

### Beyond MVP
- [x] AI bot players to fill empty slots
- [x] In-game chat
- [x] Dark/light theme toggle
- [x] Landing page with rules explanation
- [x] Multiple concurrent games (via dynamic rooms)

---

## NOT IMPLEMENTED

- Auth
- Persistence (games are in-memory only)
- Classic mode (7-round variant)
- Powerups
- Cosmetics
- Mobile optimization

---

## SUCCESS METRIC

9 friends play it at a bar and someone yells "WHAT?!" at the reveal.
