# Lura Memory Game Helper — Ace3 Migration Plan

## Goal
Convert the addon into a cleaner, more maintainable structure without changing the core gameplay behavior, the fixed arc layout, or the encounter workflow.

## Current verified baseline
**Stable branch:** `v1.5.28`  
This branch has been validated as functionally working after the modular UI split.

## Non-negotiable rule
Do **not** change:
- `ARC_RADIUS`
- `ARC_BOTTOM_DOWN`
- `ARC_ANGLES`
- `SEP_RADIUS_FACTOR`
- `SEP_ANGLES`
- slot mapping
- redraw ordering
- drag/drop behavior unless explicitly planned and tested

---

## Migration status summary

### Completed
- AceDB-3.0 migration
- AceConsole-3.0 migration
- AceTimer-3.0 migration
- Minimap / LibDataBroker / LibDBIcon integration
- Settings window split
- UI split into:
  - `UI_Main.lua`
  - `UI_Controls.lua`
  - `UI_Arc.lua`
  - `UI_Layout.lua`
- Cleanup pass for duplicate exports / stale bindings
- README now needs to be kept in sync with each functional milestone

### Not yet completed
- `Pattern.lua`
- Core API consolidation / export cleanup
- Commenting pass across modules
- Final README / architecture sync after each pass
- `Pattern.lua`
- `Broadcast.lua`
- Core API consolidation / export cleanup
- Commenting pass across modules
- Final README / architecture sync after each pass

---

## Recommended migration order

### Phase 1 — Infrastructure only
This phase is complete.

#### Step 1 — AceDB-3.0 ✅
Replaced manual persistence responsibilities:
- `initializeDB()`
- `saveWindowState()`
- `saveSettingsState()`

Persisted data:
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

#### Step 2 — AceConsole-3.0 ✅
Preserved commands:
- `/lmg`
- `/memorygame`
- `/luramemory`
- `show`
- `hide`
- `clear`
- `say`
- `undo`
- `redo`
- `lock`
- `unlock`
- `locksend on|off`
- `sendlock on|off`
- `settings`
- `minimap`
- `changelog`
- `restorefull`

#### Step 3 — AceTimer-3.0 ✅
Implemented timer use for:
- auto-clear pattern after delay

Current behavior:
- timer starts only after send
- timer clears pattern safely
- timer unlocks on clear

---

## Phase 2 — Modular split

### Current file structure
```text
LuraMemoryGameHelper/
  LuraMemoryGameHelper.toc
  Core.lua
  DB.lua
  Commands.lua
  Timer.lua
  Minimap.lua
  Settings.lua
  UI_Main.lua
  UI_Controls.lua
  UI_Arc.lua
  UI_Layout.lua
  libs/
  Textures/
```

### Current module responsibilities

#### Core.lua
- addon state
- startup flow
- shared helpers
- remaining gameplay logic
- current event handling
- remaining pattern logic
- remaining broadcast logic

#### DB.lua
- AceDB setup
- defaults
- profile read/write helpers

#### Commands.lua
- slash command registration
- command routing

#### Timer.lua
- auto-clear timer
- timer start/reset/cancel helpers

#### Minimap.lua
- LibDataBroker launcher
- LibDBIcon registration

#### Settings.lua
- settings window
- settings UI interactions

#### UI_Main.lua
- outer frame
- title
- collapse
- resize
- decorative art

#### UI_Controls.lua
- buttons
- difficulty dropdown
- RW checkbox
- symbol button row

#### UI_Arc.lua
- arc icon widgets
- separators
- placeholder visuals
- redraw logic

#### UI_Layout.lua
- frame/layout repositioning and sizing

---

## Remaining target structure
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
  UI_Controls.lua
  UI_Arc.lua
  UI_Layout.lua
  Pattern.lua
  Broadcast.lua
  libs/
  Textures/
```

---

## Next recommended migration order

### Phase 3 — Safe logic extraction

#### Step 4 — Events.lua ✅
Move event wiring out of `Core.lua`:
- `ADDON_LOADED`
- `CHAT_MSG_SAY`
- `GROUP_ROSTER_UPDATE`
- `PLAYER_ENTERING_WORLD`
- `ZONE_CHANGED_NEW_AREA`

**Why next:**  
This is the safest remaining structural split because it is mostly orchestration and event registration, not arc behavior.

#### Step 5 — Broadcast.lua ✅
Move chat/broadcast responsibilities:
- outgoing `/say`
- outgoing raid warning
- incoming `[LMG]` parsing
- permission gating helpers tied to broadcast flow

**Why before Pattern.lua:**  
Broadcast behavior is separable and easier to validate independently than the full pattern state machine.

#### Step 6 — Pattern.lua
Move:
- state table helpers
- add/move/swap/clear logic
- undo/redo
- lock state helpers
- autofill
- save/restore full pattern helpers

**Important:**  
This is the most sensitive remaining logic split and should be done only after `Events.lua` and `Broadcast.lua` are stable.

---

## Commenting standard (new requirement)

All future passes should add comments while moving code.

### Required comment types
1. **Module header**
   - purpose of file
   - what it owns
   - what it intentionally does **not** own

2. **Section headers**
   - group related helpers
   - mark exported API blocks
   - separate UI, state, event, and broadcast regions

3. **Non-obvious behavior comments**
   - drag/drop state flow
   - slot index ↔ visual index mapping
   - timer start/cancel behavior
   - lock behavior
   - raid difficulty behavior

4. **Bridge/export comments**
   - when a module consumes `LMG.*`, note that it is using the shared bridge API rather than direct locals

### Commenting rule
Comments should explain:
- **why** the code exists
- **what contract** it maintains
- **what must not change**

Avoid comments that merely restate obvious single-line Lua statements.

---

## Testing plan after each pass

### After Events.lua
Verify:
- addon still loads
- changelog still appears correctly
- auto-initialize still works
- target raid detection still works
- chat sync still works

### After Broadcast.lua
Verify:
- `/say` output unchanged
- `/rw` output unchanged
- incoming pattern sync unchanged
- incoming pattern starts/reset local timer
- self-sync test toggle works for local parsing tests
- permission gating unchanged

### After Pattern.lua
Verify:
- drag and drop still works
- filled → filled swap still works
- filled → empty move still works
- click-to-clear still works
- undo/redo still works
- autofill still works
- lock state still works
- timer still interacts correctly with pattern state

---

## Immediate implementation sequence

### Current phase
We are **past** infrastructure and UI modularization.

### Next pass
1. update migration docs
2. update README
3. begin adding comments to existing modules
4. split `Events.lua` ✅
5. continue with `Broadcast.lua`
6. continue with `Pattern.lua`

---

## Recommendation
Use **v1.5.31** as the working baseline and continue with:
1. documentation sync
2. comments
3. `Pattern.lua` next
