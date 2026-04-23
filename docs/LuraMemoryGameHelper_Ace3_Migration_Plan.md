# Lura Memory Game Helper — Ace3 Migration Plan

## Goal
Convert the addon into a cleaner, more maintainable structure without changing the core gameplay behavior or arc layout.

## Non-negotiable rule
Do **not** change:
- ARC_RADIUS
- ARC_BOTTOM_DOWN
- ARC_ANGLES
- SEP_RADIUS_FACTOR
- SEP_ANGLES
- slot mapping
- redraw ordering
- drag/drop behavior unless explicitly planned

---

## Recommended migration order

### Phase 1 — Infrastructure only
Replace fragile plumbing first. No behavior changes intended. - DONE

#### Step 1 — AceDB-3.0 - DONE
Move all manual SavedVariables handling into AceDB.

Current manual persistence to replace:
- initializeDB()
- saveWindowState()
- saveSettingsState()

Data to move:
- window width / height
- window point / relativePoint / x / y
- collapsed state
- autoFill
- preventDuplicates
- lockAfterSend
- alsoSendRW
- changelogDismissedVersion
- difficultyMode
- minimap.hide
- minimap.minimapPos

Target defaults:
```lua
local defaults = {
  profile = {
    window = {
      width = 395,
      height = 535,
      point = "CENTER",
      relativePoint = "CENTER",
      x = 200,
      y = 80,
      collapsed = false,
    },
    settings = {
      autoFill = true,
      preventDuplicates = true,
      lockAfterSend = false,
      alsoSendRW = false,
      changelogDismissedVersion = "",
      difficultyMode = "auto",
    },
    minimap = {
      hide = false,
      minimapPos = 220,
    },
  },
}
```

#### Step 2 — AceConsole-3.0 - DONE
Move slash command parsing into AceConsole.

Commands to preserve:
- /lmg
- /memorygame
- /luramemory
- show
- hide
- clear
- say
- undo
- redo
- lock
- unlock
- locksend on|off
- sendlock on|off
- settings
- minimap
- changelog
- restorefull

#### Step 3 — AceTimer-3.0 - DONE
Use timers for delayed functionality.

First timer use:
- auto-clear pattern after 45 seconds

Future timer uses:
- delayed unlocks
- transient notifications
- encounter timers

---

## Phase 2 — Split into modules

### Proposed file structure
```text
LuraMemoryGameHelper/
  LuraMemoryGameHelper.toc
  Core.lua
  DB.lua
  Commands.lua
  Events.lua
  Timer.lua
  Minimap.lua
  Settings.lua
  UI_Main.lua
  UI_Arc.lua
  Pattern.lua
  Broadcast.lua
  libs/
  Textures/
```

### Module responsibilities

#### Core.lua
- create addon object
- initialize Ace3 mixins
- startup sequence

#### DB.lua
- AceDB setup
- defaults
- wrappers/helpers for profile access

#### Commands.lua
- slash commands
- parsing
- command routing

#### Events.lua
- ADDON_LOADED
- CHAT_MSG_SAY
- GROUP_ROSTER_UPDATE
- PLAYER_ENTERING_WORLD
- ZONE_CHANGED_NEW_AREA

#### Timer.lua
- auto-clear timer
- timer start/reset/cancel helpers

#### Minimap.lua
- LibDataBroker launcher
- LibDBIcon registration

#### Settings.lua
- settings window
- dropdowns
- config controls

#### UI_Main.lua
- outer frame
- title
- collapse
- resize
- decorative art

#### UI_Arc.lua
- arc icon widgets
- separator widgets
- placeholders
- redraw visuals only

#### Pattern.lua
- state table
- add/move/swap/clear logic
- undo/redo
- lock state
- autofill
- future mythic alternating fill direction

#### Broadcast.lua
- outgoing /say
- outgoing raid warning
- permission logic
- incoming pattern parsing

---

## First safe implementation target

### Milestone A
Stay in one file temporarily, but convert:
- manual DB → AceDB
- manual slash commands → AceConsole
- timer plumbing → AceTimer

Do **not** split files yet.

Why:
- easier rollback
- easier testing
- lower risk to arc behavior

---

## Testing plan after each pass

### After AceDB
Verify:
- window position saves
- window size saves
- collapse state saves
- toggles persist
- minimap button state persists
- changelog dismissal persists

### After AceConsole
Verify:
- all slash commands still work
- subcommands still behave the same
- no alias regressions

### After AceTimer
Verify:
- 45-second auto-clear fires correctly
- timer resets on board change
- timer cancels on manual clear
- timer does not break lock state

### After modular split
Verify:
- drag and drop still works
- empty slot move still works
- undo/redo still works
- difficulty mode still works
- send / clear still works
- collapse still hides everything except the title

---

## Immediate implementation sequence

### Pass 1
Introduce:
- AceAddon-3.0
- AceDB-3.0
- AceConsole-3.0
- AceTimer-3.0

### Pass 2
Replace:
- initializeDB()
- saveWindowState()
- saveSettingsState()

with AceDB-backed reads/writes.

### Pass 3
Move slash commands into AceConsole.

### Pass 4
Implement 45-second auto-clear with AceTimer.

### Pass 5
Split out Minimap.lua and Settings.lua.

### Pass 6
Split Pattern.lua and Broadcast.lua.

### Pass 7
Split UI_Main.lua and UI_Arc.lua last.

---

## Recommendation
Start with **AceDB only**. It gives the biggest maintenance win with the least risk.
