# Lura Memory Game Helper

Version: 1.0.5

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
- `/say` pattern broadcasting
- optional raid warning output
- raid leader / assistant permission checks for broadcast actions
- auto-open behavior for the target raid
- manual open / hide through slash commands
- dynamic layout refresh on resize
- texture-based custom frame and controls

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

## Pattern behavior

### Pattern entry

The bottom row contains five symbol buttons:

- Diamond
- Triangle
- Circle
- Cross
- T

Clicking a symbol appends it to the current pattern until the pattern reaches five entries.

Internally, the pattern is stored in `state`.

### Arc display order

The addon stores pattern entries in normal input order, but displays them visually right-to-left in the upper arc.

That means:

- first click appears in slot 5
- second click appears in slot 4
- third click appears in slot 3
- fourth click appears in slot 2
- fifth click appears in slot 1

This behavior is handled in `redraw()`.

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

