# Lura Memory Game Helper
Version: 1.4.4

Created by Tinaria

Inspired by Lura Tily Helper by tilynye.

It has evolved into something so much more. many features in such a tiny box. 

---

## Some Upfront information

Must be Raidlead or Assist for /RW broadcasting to function unless you go into test mode 
(/lmg test) I'll add a solo option soon enough if it becomes nessacary.

It will broadecast to /say as [LMG] PATTERN: 1 , 2 , 3 , 4 , 5 I'm hoping this works out
to populate others addons. if not it will still send the standard /rw message that everone gets.
let's see what happens!

---

### Overview
Lura Memory Game Helper is a World of Warcraft addon designed for the L’ura encounter. It provides a fast, visual system to build, manage, and broadcast memory patterns using a consistent arc-based layout.

The addon emphasizes:
- speed
- clarity
- minimal input friction
- consistent spatial memory (arc layout never changes)

**Full on Disclaimer** 
- I have no idea if the broadcasting to other people with the addon will work at the moment. It will require testing. I have built in a fallback with the raidwarning however.
- I plan to implement additional visual clarity in a near future update that will hopefully clear the confusion

- Cross = Raid Marker X (Cross) red
- Diamond = Raid Marker ♦ (diamond) purple
- Triangle = Raid Marker ▼ (triangle) green
- Bullseye = Raid Marker O (circle) orange
- T/Nail = Raid Marker ★ (star) yellow

- I am hoping this will be enough of a fallback it becomes a viable workaround for those that need this addon
---

####

On the list for the near future

- Minimap Icon and ability to move it to the add-on compartment
- Settings window
- True Scaling, not this drag a corner crap
- Code moved into a modular structure to make my life easier (I never expected it to get this out of hand)

- This is the end of my babbeling 

#### #######################################################################################################################################################################################################

### Current Feature Set (v1.4.4)

### Pattern Interaction
- Five-slot internal pattern system
- Visual arc display (right-to-left mapping)
- Click symbol buttons to insert
- Click arc slots to clear individual positions
- Drag-and-drop:
  - filled → filled = swap
  - filled → empty = move

---

### Smart Pattern Logic
- Duplicate prevention
- Smart autofill:
  - fills final remaining slot automatically
  - works after drag, swap, clear, undo
- Auto-filled entries are visually dimmed

---

### State Management
- /lmg undo → restores previous state
- /lmg redo → restores last full pattern
- Stable state handling across all interactions

---

### Lock System
- /lmg locksend on|off
- When enabled:
  - pattern locks after sending
  - prevents accidental edits
- Requires clear or unlock to modify

---

### Difficulty System
Supports dynamic slot modes:

Normal:
- Uses 3 slots (2,3,4)

Heroic / Mythic:
- Uses all 5 slots - Mythic will have the CW/CCW logic added shortly. it requires some extra trickery

Dropdown options:
- Auto
- Normal (3)
- Heroic (5)
- Mythic (5) (this still needs the clockwise/counter clockwise logic added. Give me a week or so to get to it!)

---

### UI Features
- Movable window
- Resizable frame
- Minimize / expand
- Dynamic layout scaling
- Texture-based UI
- Custom icon system

---

### UI Polish (v1.4.4)
- Centered difficulty dropdown
- Boss label repositioned and resized
- Improved frame background
- Hover feedback for:
  - arc slots
  - buttons
  - symbols
  - checkbox
- Lock status indicator added

---

## Commands

### Core
/lmg
/memorygame
/luramemory

### Window
/lmg show
/lmg hide

### Pattern
/lmg clear
/lmg say
/lmg undo
/lmg redo

### System
/lmg locksend on
/lmg locksend off
/lmg test

---

## Pattern Behavior

### Storage vs Display
Internally:
slot 1 → visual slot 5  
slot 2 → visual slot 4  
slot 3 → visual slot 3  
slot 4 → visual slot 2  
slot 5 → visual slot 1  

Handled in redraw()

---

### Autofill Behavior
Triggers when:
- one empty slot
- one unused symbol

Works after:
- drag
- swap
- clear
- undo

---

## Broadcast Behavior

Send output:
/say → [LMG] PATTERN: Diamond > Triangle > ...

Raid warning (optional):
>>> DIAMOND <> TRIANGLE <> CIRCLE <> CROSS <> tTt <<<

---

### Permissions
Broadcast allowed only if:
- test mode enabled OR
- player is raid leader or assistant

Otherwise:
- send disabled
- clear disabled
- RW checkbox disabled

---

## Layout System

Uses shared arc constants:

ARC_RADIUS  
ARC_BOTTOM_DOWN  
ARC_ANGLES  
SEP_RADIUS_FACTOR  
SEP_ANGLES  

Arc positioning is fixed and not modified by UI changes.

---

## Textures

Path:
Interface\AddOns\LuraMemoryGameHelper\Textures\

Includes:
- frame assets
- buttons
- checkbox
- separators
- symbol icons

---

## Core Functions

Layout:
recomputeSlots()
applyLayout()

UI:
buildMainFrame()
buildTitleBar()
buildArcDisplay()
buildDifficultyDropdown()
buildActionButtons()
buildSymbolButtons()

Pattern:
addSymbol()
clearState()
sendPattern()
saveUndoState()
restoreUndoState()

Systems:
applyRaidDifficultyPatternMode()
playerCanBroadcast()
updateBroadcastControls()

---

## Changelog

### v1.4.4 — UI Polish
- centered dropdown
- resized boss label
- hover effects added
- improved visuals
- lock status indicator added

### v1.4.x — Difficulty System
- 3-slot vs 5-slot modes
- dropdown override

### v1.3.x — Lock + Redo
- locksend system
- redo system
- stability fixes

### v1.2.x — Smart Autofill
- dynamic autofill logic
- improved interaction stability

### v1.1.x — Drag System
- drag and drop
- swapping
- slot targeting fixes

### v1.0.0 — Initial Release
- core functionality
- arc display