# Lura Memory Game Helper

Version: 1.5.31

Created by Tinaria

Inspired by Lura Tily Helper by tilynye.

---

## Some Upfront Information

Must be Raid Lead or Assist for `/rw` broadcasting unless using test mode:

```text
/lmg test
```

Broadcast behavior:
- `/say` → `[LMG] PATTERN: ...`
- `/rw` → fallback formatted message

---

## Overview

Lura Memory Game Helper is a World of Warcraft addon for the L’ura encounter (midnight Falls). It provides a fast, visual system to build, manage, and broadcast memory patterns using a fixed arc-based layout.

The addon emphasizes:
- speed
- clarity
- minimal input friction
- consistent spatial memory

**The arc layout is not dynamically redesigned.**

---

## Symbol Mapping

- Cross = Raid Marker X (red)
- Diamond = ♦ (purple)
- Triangle = ▼ (green)
- Circle = O (orange)
- T / Star = ★ (yellow)

---

## Current Feature Set

### Pattern Interaction
- five-slot internal pattern system
- visual arc display with right-to-left internal mapping
- click symbol buttons to insert
- click arc slots to clear
- drag-and-drop:
  - filled → filled = swap
  - filled → empty = move

### Smart Pattern Logic
- duplicate prevention
- smart autofill for the last remaining slot
- autofill survives drag, swap, clear, and undo flow
- auto-filled entries are dimmed

### State Management
- `/lmg undo`
- `/lmg redo`
- restore last full pattern support
- stable lock / unlock behavior

### Difficulty System
Supports dynamic slot modes:

**Normal**
- 3 slots (2, 3, 4)

**Heroic / Mythic**
- 5 slots

Dropdown modes:
- Auto
- Normal (3)
- Heroic (5)
- Mythic (5)

### Auto-Clear Timer
- timer starts only after pattern send
- timer clears pattern automatically after delay
- timer unlocks on clear

Current config:
```lua
AUTO_CLEAR_SECONDS = 10
```

### Minimap Button
- LibDataBroker + LibDBIcon based
- draggable
- works with circular minimap
- works with square minimap
- works with ElvUI addon compartment
- left click → toggle main window
- right click → open settings

### Settings Window
- toggle autofill
- toggle duplicate prevention
- toggle lock-after-send
- toggle raid warning
- difficulty override dropdown
- test mode toggle
- changelog access

### Persistent Data
Backed by AceDB:
- window position
- window size
- collapse state
- settings
- minimap position / hidden state
- changelog dismissal state

### Command System
Backed by AceConsole:
- `/lmg`
- `/memorygame`
- `/luramemory`

---

## Commands

### Core
```text
/lmg
/memorygame
/luramemory
```

### Window
```text
/lmg show
/lmg hide
/lmg settings
/lmg minimap
```

### Pattern
```text
/lmg clear
/lmg say
/lmg undo
/lmg redo
/lmg restorefull
```

### Lock / Test
```text
/lmg lock
/lmg unlock
/lmg locksend on
/lmg locksend off
/lmg test
```

### Informational
```text
/lmg changelog
/lmg selfsync on
/lmg selfsync off
```

---

## Pattern Behavior

### Storage vs Display

Internal → Visual

```text
1 → 5
2 → 4
3 → 3
4 → 2
5 → 1
```

Handled by the arc redraw logic.

### Autofill Behavior
Autofill triggers when:
- exactly one empty active slot remains
- exactly one unused symbol remains

---

## Broadcast Behavior

### Output
```text
/say → [LMG] PATTERN: Diamond > Triangle > Circle > Cross > T
```

Optional `/rw`:
```text
>>> DIAMOND <> TRIANGLE <> CIRCLE <> CROSS <> T <<<
```

### Permissions
Broadcasting is allowed if:
- test mode is enabled, or
- the player is raid leader / assistant

Otherwise:
- send is disabled
- clear broadcast is disabled
- RW is disabled

---

## Layout System

Uses fixed arc constants:
- `ARC_RADIUS`
- `ARC_BOTTOM_DOWN`
- `ARC_ANGLES`
- `SEP_RADIUS_FACTOR`
- `SEP_ANGLES`

These are intentionally not modified dynamically.

---

## Current Architecture

### Ace3 / library foundation
- AceDB → persistence
- AceConsole → commands
- AceTimer → delayed logic
- LibDataBroker → launcher
- LibDBIcon → minimap integration

### Current module layout
```text
Events.lua
Core.lua
DB.lua
Commands.lua
Events.lua
Broadcast.lua
Timer.lua
Minimap.lua
Settings.lua
UI_Main.lua
UI_Controls.lua
UI_Arc.lua
UI_Layout.lua
```

### What still remains in Core
`Core.lua` still owns:
- remaining event flow
- pattern state machine
- broadcast/chat logic
- shared bridge exports used by the modular files

---

## Migration Status

### Completed
- AceDB migration
- AceConsole migration
- AceTimer migration
- minimap split
- settings split
- UI split into main / controls / arc / layout modules

### Next planned modules
- `Events.lua`
- `Broadcast.lua`
- `Pattern.lua`

---

## Known Behavior Notes
- timer starts after local send and after receiving an incoming `[LMG] PATTERN:` sync
- timer clears locked patterns safely
- UI modules communicate through exported `LMG.*` bridge functions
- arc behavior is preserved during migration and should not be changed casually

---

## Changelog

### v1.5.31
- extracted `Broadcast.lua`
- moved outgoing /say, RW formatting, and incoming payload parsing into a dedicated module
- left `[LMG] CLEAR` fully commented out as a non-functional backup path
- added module headers and section comments for broadcast flow

### v1.5.30
- incoming `[LMG] PATTERN:` now starts/resets the local auto-clear timer
- added self-sync test toggle for local incoming `/say` testing
- `[LMG] CLEAR` left commented out as a backup-only, non-functional path

### v1.5.29
- moved WoW event registration into `Events.lua`
- began module header and section comment pass

### v1.5.28
- verified stable modular baseline
- UI modules split into:
  - `UI_Main.lua`
  - `UI_Controls.lua`
  - `UI_Arc.lua`
  - `UI_Layout.lua`
- cleanup pass for duplicate / stale exports
- documentation refresh started

### v1.5.x — Ace3 Foundation
- AceDB integration
- AceConsole command system
- AceTimer auto-clear system
- LibDBIcon minimap button
- settings window added
- forward declaration fixes for async callbacks

### v1.4.4 — UI Polish
- centered dropdown
- resized boss label
- hover effects
- improved visuals
- lock status indicator

### v1.3.x — Lock + Redo
- locksend system
- redo system

### v1.2.x — Smart Autofill
- autofill logic improvements

### v1.1.x — Drag System
- drag and drop
- swapping
- slot targeting fixes

### v1.0.0 — Initial Release
- core functionality
- arc display

---

## Future Plans
- split `Events.lua`
- split `Broadcast.lua`
- split `Pattern.lua`
- improve inline comments / module headers

