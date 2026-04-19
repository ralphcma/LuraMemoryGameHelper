# Lura Memory Game Helper

Version: 1.2.0

Created by Tinaria

Inspired by **Lura Tily Helper** by tilynye.

## Overview

Lura Memory Game Helper is a World of Warcraft addon that provides a visual memory-pattern helper UI for the L'ura encounter. It displays a five-slot arc of symbol icons, lets the user build a pattern from clickable symbol buttons, and can broadcast that pattern to chat.

This documentation reflects the **current cleaned script** and removes older layout methods that are no longer used.

## Current feature set

The addon currently provides:

- a movable, resizable window
- a five-slot visual arc display
- clickable symbol entry buttons
- clickable arc slots for per-slot clearing
- drag-and-drop movement and swapping between populated slots
- duplicate prevention
- smart auto-fill of the only remaining empty slot
- visual distinction for auto-filled entries
- `/say` pattern broadcasting
- optional raid warning output
- raid leader / assistant permission checks for broadcast actions
- auto-open behavior for the target raid
- manual open / hide through slash commands
- dynamic layout refresh on resize
- texture-based custom frame and controls
- one-step undo support

## Current slash commands

Main commands:

- `/lmg`
- `/memorygame`
- `/luramemory`

Extra commands:

- `/lmg show`  
  Shows the addon window.

- `/lmg hide`  
  Hides the addon window.

- `/lmg clear`  
  Clears the pattern and sends the clear message, if broadcasting is allowed.

- `/lmg say`  
  Sends the current pattern, if broadcasting is allowed.

- `/lmg test`  
  Toggles test mode so you can test broadcast functionality outside the raid.

- `/lmg undo`  
  Restores the previous pattern state.

## Pattern behavior

### Pattern entry

The bottom row contains five symbol buttons:

- Diamond
- Triangle
- Circle
- Cross
- T

Clicking a symbol fills the **first available empty slot**.

Internally, the pattern is stored in `state` as a fixed 5-slot model.

### Arc display order

The addon stores pattern entries in normal input order, but displays them visually right-to-left in the upper arc.

That means:

- slot 1 appears in visual slot 5
- slot 2 appears in visual slot 4
- slot 3 appears in visual slot 3
- slot 4 appears in visual slot 2
- slot 5 appears in visual slot 1

This behavior is handled in `redraw()`.

### Slot editing

Each arc slot can now be edited directly:

- **Click a filled slot** to clear that specific position
- **Drag a filled slot onto another filled slot** to swap them
- **Drag a filled slot onto an empty slot** to move it there

Empty slots show a visible marker so drop targets are easier to see.

### Auto-fill behavior

If exactly one symbol remains unused and exactly one slot is empty, the addon can auto-fill that final slot.

This now works from the **current board state**, not only from the original fill order, so it behaves correctly after:

- manual fills
- clears
- swaps
- drag moves
- undo
- imported patterns

Auto-filled slots are visually dimmed so they can be distinguished from manual entries.

### Duplicate prevention

Duplicate prevention blocks placing the same symbol more than once when enabled.

If a duplicate is attempted, the addon gives feedback instead of inserting it.

### Clear behavior

The Clear button:

- wipes the current local pattern
- redraws the arc
- optionally sends `[LMG] CLEAR` to `/say`

### Send behavior

The Send button broadcasts the current pattern as:

`[LMG] PATTERN: Diamond > Triangle > Circle > ...`

If the raid warning checkbox is enabled, the addon also sends:

`>>> DIAMOND <> TRIANGLE <> CIRCLE <> CROSS <> tTt <<<`

The `T` symbol is intentionally converted to `tTt` in the raid warning output.

### Undo behavior

The addon supports one-step undo of the most recent edit action.

## Broadcast permission rules

Broadcast actions are allowed only when:

- test mode is enabled, or
- the player is in a raid and is either:
  - raid leader
  - raid assistant

If broadcast permission is unavailable:

- Send is disabled
- Clear is disabled
- the `/rw` checkbox is disabled
- the checkbox is reset off

This behavior is controlled by:

- `playerCanBroadcast()`
- `updateBroadcastControls()`

## Auto-open behavior

The addon auto-opens only in:

- `March on Quel'Danas`

Relevant logic:

- `TARGET_RAID_NAME`
- `inTargetRaid()`
- `autoHandleTargetRaid()`

The addon can still be opened anywhere with slash commands.

## Current layout system

The current script uses a **shared radius-based arc system**.

Older direct slot-by-slot placement documentation has been removed because the cleaned script now centralizes arc settings.

### Shared arc constants

The cleaned script uses these shared constants:

- `ARC_RADIUS`
- `ARC_BOTTOM_DOWN`
- `ARC_ANGLES`
- `SEP_RADIUS_FACTOR`
- `SEP_ANGLES`

These are used consistently by:

- `recomputeSlots()`
- `buildArcDisplay()`
- `applyLayout()`

### What each arc constant does

#### `ARC_RADIUS`

Controls the overall size of the icon arc.

- larger value = larger arc
- smaller value = tighter arc

#### `ARC_BOTTOM_DOWN`

Controls how low the arc sits in the frame.

- larger value = whole arc moves lower
- smaller value = whole arc moves higher

#### `ARC_ANGLES`

Controls the icon spread around the arc.

Order:

- first = slot 1
- second = slot 2
- third = slot 3
- fourth = slot 4
- fifth = slot 5

Angles farther from 90 spread icons outward more.

#### `SEP_RADIUS_FACTOR`

Controls how far separators sit from the center relative to the icon arc.

- larger factor = separators farther outward
- smaller factor = separators more inward

#### `SEP_ANGLES`

Controls the four separator positions between the five icons.

Order:

- between slot 1 and slot 2
- between slot 2 and slot 3
- between slot 3 and slot 4
- between slot 4 and slot 5

### Shared geometry helpers

The cleaned script now uses:

- `getArcGeometry()`
- `buildSeparatorPoints()`

These exist to prevent the old issue where separator layout and icon layout could drift out of sync.

## Window behavior

The window supports:

- dragging
- resizing from the bottom-right corner
- minimize / expand
- dynamic layout refresh

Sizing and positioning settings live in the `UI` table.

Important values include:

- `width`
- `height`
- `minWidth`
- `minHeight`
- `maxWidth`
- `maxHeight`
- `collapsedHeight`

## Textures used by the current script

Expected texture path:

`Interface\AddOns\LuraMemoryGameHelper\Textures\`

### Frame
- `frame_corner_tl.tga`
- `frame_corner_tr.tga`
- `frame_corner_bl.tga`
- `frame_corner_br.tga`
- `frame_border_top.tga`
- `frame_border_bottom.tga`
- `frame_border_left.tga`
- `frame_border_right.tga`

### Header and label
- `title.tga`
- `bosslabel.tga`

### Buttons
- `btn_clear.tga`
- `btn_clear_down.tga`
- `btn_send.tga`
- `btn_send_down.tga`

### Checkbox
- `checkbox_unchecked.tga`
- `checkbox_checked.tga`
- `checkbox_text.tga`

### Symbol icons
- `sym_diamond.tga`
- `sym_triangle.tga`
- `sym_circle.tga`
- `sym_cross.tga`
- `sym_t.tga`

### Separators
- `sym_separator.tga`
- `thin_separator.tga`

## Current core functions

### Geometry and layout
- `getArcGeometry()`
- `buildSeparatorPoints()`
- `recomputeSlots()`
- `applyLayout()`

### UI construction
- `buildMainFrame()`
- `buildTitleBar()`
- `buildArcDisplay()`
- `buildActionButtons()`
- `buildRWCheckbox()`
- `buildSymbolButtons()`
- `buildWindow()`

### Pattern handling
- `redraw()`
- `clearState()`
- `addSymbol()`
- `sendPattern()`
- `doClear()`
- `saveUndoState()`
- `restoreUndoState()`

### Chat parsing
- `parsePayload()`
- `handleSayMessage()`
- `textToPattern()`

### Permissions and visibility
- `playerCanBroadcast()`
- `updateBroadcastControls()`
- `showWindow()`
- `hideWindow()`
- `toggleWindow()`
- `setCollapsed()`
- `toggleCollapsed()`

## Removed documentation from older builds

The following older documentation topics were intentionally removed because they no longer reflect the cleaned script:

- direct manual slot tables as the primary system
- duplicated per-section separator tuning as the intended workflow
- mixed old and new arc placement methods
- outdated references to earlier UI tuning experiments that were not kept in the final cleaned version

## Changelog

## ============================================================
## Lura Memory Game Helper — Changelog
## ============================================================

### **v1.2.0 — Phase 1 Polish + Smart Autofill**
- Reworked autofill logic:
  - now fills the **only remaining empty slot** instead of forcing slot 5
  - works correctly after drag, swap, clear, and undo
- Added **auto-filled slot tracking**
  - auto-filled icons are now visually dimmed
- Improved editing flow:
  - clearing a manual slot removes auto-filled slots to prevent instant re-fill conflicts
- Enhanced UI clarity:
  - empty slots now display a **visible marker** for easier targeting
- Improved tooltips:
  - show slot position
  - show symbol name
  - indicate auto-filled slots
  - explain click/drag behavior
- Improved duplicate prevention feedback:
  - now displays clearer on-screen error messaging
- General stability improvements to drag + state handling

### **v1.1.4 — Stable Drag Foundation**
- Established stable drag-and-drop system:
  - drag filled → filled = **swap**
  - drag filled → empty = **move**
- Fixed multiple drag edge cases:
  - empty slot targeting issues
  - hover detection inconsistencies
- Added fallback targeting using mouse focus
- Introduced placeholder markers for empty slots
- Improved slot interaction consistency across all states

### **v1.1.3 — Drag Target Fix Attempts**
- Adjusted redraw logic so empty slots remain interactable
- Began addressing inability to drop onto empty slots
- Identified limitations of original drag model

### **v1.1.2 — Initial Drag + Undo Implementation**
- Added drag-and-drop interaction (first iteration)
- Added `/lmg undo` command
- Introduced state snapshot system
- Fixed redraw scope issues causing nil errors

### **v1.1.1 — Drag Fix Pass**
- Improved drag handling reliability
- Fixed tooltip conflicts interfering with drag tracking
- Improved swap behavior between populated slots

### **v1.1.0 — Interaction Expansion**
- Added clickable arc slots:
  - click to clear individual positions
- Added duplicate prevention logic
- Added initial slot 5 auto-fill behavior
- Began transition from linear sequence → slot-based system

### **v1.0.5 — UI Refinement**
- Improved arc layout and positioning
- Adjusted icon spacing and separator alignment
- Improved frame sizing and visual balance
- Added better scaling support within window constraints

### **v1.0.0 — Initial Release**
- Core L’ura memory helper functionality
- Arc-based visual pattern display
- Symbol input system
- Pattern broadcast via `/say`
- Optional raid warning broadcast
- Basic UI with manual interaction
- Slash command support:
  - `/lmg`
  - `/memorygame`
  - `/luramemory`
