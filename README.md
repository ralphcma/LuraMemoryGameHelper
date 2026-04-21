# Lura Memory Game Helper

Version: 1.5.10

Created by Tinaria

Inspired by Lura Tily Helper by tilynye.

---

## Some Upfront Information

Must be Raid Lead or Assist for /RW broadcasting unless using test mode:

```
/lmg test
```

Broadcast behavior:

* `/say` → `[LMG] PATTERN: 1 , 2 , 3 , 4 , 5`
* `/rw` → fallback formatted message

---

## Overview

Lura Memory Game Helper is a World of Warcraft addon designed for the L’ura encounter. It provides a fast, visual system to build, manage, and broadcast memory patterns using a fixed arc-based layout.

The addon emphasizes:

* speed
* clarity
* minimal input friction
* consistent spatial memory (**arc layout never changes**)

---

## Symbol Mapping

* Cross = Raid Marker X (red)
* Diamond = ♦ (purple)
* Triangle = ▼ (green)
* Circle = O (orange)
* T / Star = ★ (yellow)

---

## Current Feature Set (v1.5.x)

### Pattern Interaction

* Five-slot internal pattern system
* Visual arc display (right-to-left mapping)
* Click symbol buttons to insert
* Click arc slots to clear
* Drag-and-drop:

  * filled → filled = swap
  * filled → empty = move

---

### Smart Pattern Logic

* Duplicate prevention
* Smart autofill (final slot auto-filled)
* Works after:

  * drag
  * swap
  * clear
  * undo
* Auto-filled entries are dimmed

---

### State Management

* `/lmg undo` → restore previous state
* `/lmg redo` → restore last full pattern
* Stable state handling

---

### Lock System

* `/lmg locksend on|off`
* Locks pattern after send
* Prevents accidental edits
* Requires clear or unlock

---

### Difficulty System

Supports dynamic slot modes:

**Normal**

* 3 slots (2,3,4)

**Heroic / Mythic**

* 5 slots

Dropdown:

* Auto
* Normal (3)
* Heroic (5)
* Mythic (5)

---

## 🆕 New Systems (v1.5.x)

### Minimap Button (LibDataBroker + LibDBIcon)

* Fully draggable
* Works with:

  * circular minimap
  * square minimap
  * ElvUI addon compartment
* Left click → toggle window
* Right click → settings

---

### Settings Window

* Toggle autofill
* Toggle duplicate prevention
* Toggle lock-after-send
* Toggle raid warning
* Difficulty override dropdown
* Test mode toggle
* Changelog access

---

### Auto-Clear Timer (AceTimer-3.0)

* Starts **only after pattern is sent**
* Clears pattern automatically after delay
* Unlocks pattern on clear

Config:

```lua
AUTO_CLEAR_SECONDS = 10 -- change this for testing / tuning
```

---

### Persistent Data (AceDB-3.0)

* Window position
* Window size
* Collapse state
* Settings
* Minimap position

---

### Command System (AceConsole-3.0)

Cleaner and more extensible command handling.

---

## Commands

### Core

```
/lmg
/memorygame
/luramemory
```

### Window

```
/lmg show
/lmg hide
```

### Pattern

```
/lmg clear
/lmg say
/lmg undo
/lmg redo
```

### System

```
/lmg locksend on
/lmg locksend off
/lmg test
/lmg settings
/lmg minimap
```

---

## Pattern Behavior

### Storage vs Display

Internal → Visual:

```
1 → 5  
2 → 4  
3 → 3  
4 → 2  
5 → 1  
```

Handled in `redraw()`

---

### Autofill Behavior

Triggers when:

* one empty slot
* one unused symbol

---

## Broadcast Behavior

### Output

```
/say → [LMG] PATTERN: Diamond > Triangle > ...
```

Optional `/rw`:

```
>>> DIAMOND <> TRIANGLE <> CIRCLE <> CROSS <> T <<<
```

---

### Permissions

Allowed if:

* test mode OR
* raid leader / assistant

Otherwise:

* send disabled
* clear disabled
* RW disabled

---

## Layout System

Uses fixed arc constants:

* ARC_RADIUS
* ARC_BOTTOM_DOWN
* ARC_ANGLES
* SEP_RADIUS_FACTOR
* SEP_ANGLES

⚠️ These are never modified dynamically.

---

## Architecture (Post Ace3 Migration)

Core systems now use:

* AceDB → persistence
* AceConsole → commands
* AceTimer → delayed logic
* LibDataBroker → launcher
* LibDBIcon → minimap

---

## Known Behavior Notes

* Timer only starts after sending pattern
* Timer clears locked patterns safely
* All async callbacks use forward-declared locals (prevents nil call errors)

---

## Changelog

### v1.5.x — Ace3 Foundation

* AceDB integration
* AceConsole command system
* AceTimer auto-clear system
* LibDBIcon minimap button
* Settings window added
* Forward declaration system (fixes async bugs)

### v1.4.4 — UI Polish 

* centered dropdown
* resized boss label
* hover effects
* improved visuals
* lock status indicator

### v1.3.x — Lock + Redo

* locksend system
* redo system

### v1.2.x — Smart Autofill

* autofill logic improvements

### v1.1.x — Drag System

* drag and drop
* swapping
* slot targeting fixes

### v1.0.0 — Initial Release

* core functionality
* arc display

---

## Future Plans

* Mythic CW/CCW alternating pattern logic
* Full modular file split (Core/UI/Pattern/etc.)
* Improved scaling system
* Additional visual clarity improvements

---
