# TIC TAC TOE, BLAST! — PRD v0.1

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
- **Classic:** 7 rounds, highest score wins

---

## TECH

Phoenix + LiveView + Daisy UI + TailwindCSS + Fly.io

- Game room = GenServer holding state
- Players connect via Phoenix Channel
- Phoenix Presence for lobby/ready state
- State machine: `lobby → center_pick → choosing → countdown → reveal → scoring → repeat`

---

## DATA MODEL

```
Game: id, mode, round, state, center_player_id, cells[], scores{}, streak{}
Player: id, name, game_id, cell_position, current_pick, score, streak_count
Cell: position (1-9), player_id, color (nil | red | blue), revealed
```

---

## MVP SCOPE

- [ ] Single game room
- [ ] Join with name
- [ ] 9-player lobby with ready states
- [ ] Random cell + center assignment
- [ ] Center pick → others pick → reveal flow
- [ ] Scoring logic
- [ ] BLAST mode win condition
- [ ] Basic UI showing board + scores

---

## NOT IN MVP

- Auth
- Persistence
- Multiple concurrent games
- Classic mode
- Powerups
- Cosmetics
- Mobile optimization

---

## SUCCESS METRIC

9 friends play it at a bar and someone yells "WHAT?!" at the reveal.

