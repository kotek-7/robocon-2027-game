---
name: Robocon 2027 Game
description: A bright toy-like competition arena for short robot matches.
colors:
  ink: "#20243e"
  cream: "#fffaf0"
  coral: "#ed174c"
  pool-blue: "#0078dd"
  mint: "#20db93"
  gold: "#ffda16"
  lilac: "#12bfe7"
  plinth: "#6028c7"
  barrier: "#4b20a5"
  cargo-empty: "#c6cee8"
  objective-inactive: "#433074"
  control-ink: "#25204e"
  hint-ink: "#433074"
typography:
  display:
    fontFamily: "Fredoka"
    fontSize: "62px"
    fontWeight: 600
  score:
    fontFamily: "Fredoka"
    fontSize: "40px"
    fontWeight: 600
  clock:
    fontFamily: "Fredoka"
    fontSize: "32px"
    fontWeight: 600
  button:
    fontFamily: "Fredoka"
    fontSize: "26px"
    fontWeight: 600
  hint:
    fontFamily: "Fredoka"
    fontSize: "13px"
    fontWeight: 600
rounded:
  tile: "18px"
  action: "29px"
spacing:
  menu-gap: "14px"
  button-inset: "24px"
components:
  button-default:
    backgroundColor: "{colors.cream}"
    textColor: "{colors.ink}"
    typography: "{typography.button}"
    rounded: "{rounded.tile}"
    width: "320px"
    height: "58px"
  button-primary:
    backgroundColor: "{colors.gold}"
    textColor: "{colors.ink}"
    typography: "{typography.button}"
    rounded: "{rounded.tile}"
    width: "320px"
    height: "58px"
  score-red:
    backgroundColor: "{colors.coral}"
    textColor: "#ffffff"
    typography: "{typography.score}"
    rounded: "{rounded.tile}"
    width: "130px"
    height: "70px"
  score-blue:
    backgroundColor: "{colors.pool-blue}"
    textColor: "#ffffff"
    typography: "{typography.score}"
    rounded: "{rounded.tile}"
    width: "130px"
    height: "70px"
  clock:
    backgroundColor: "{colors.cream}"
    textColor: "{colors.ink}"
    typography: "{typography.clock}"
    rounded: "{rounded.tile}"
    width: "140px"
    height: "62px"
---

# Design System: Robocon 2027 Game

## Overview

**Creative North Star: "Floating toy arena"**

A floating competition arena with golden-yellow platforms, vivid red and blue robots, emerald building pads and a cyan environment. Rounded shells and dark faceplates give the machines a friendly toy character while block shapes and the field retain their competitive meaning.

The arena occupies the viewport. Compact score tiles, a clock and pictorial cargo indicators leave room for driving. Menu labels are short; motion belongs to the robots and objects.

**Key Characteristics:**
- Distinct robot silhouettes and team pips accompany color.
- Fredoka Semibold carries short labels and large numerals.
- Soft UI shadows and matte 3D materials give gentle depth.

## Colors

### Primary

Coral and pool blue identify opposing teams in robots, blocks, scoring and field markings. Gold identifies Mustika, the target ring and the main play action.

### Secondary

Mint marks building areas. Lilac surrounds the floating field; deeper plinth and barrier colors anchor its underside and obstacles.

### Neutral

Cream covers platforms, clock and cargo surfaces, robot details and action prompts. Ink belongs to faceplates and readable UI text. Cargo-empty and objective-inactive distinguish unavailable progress; control-ink and hint-ink support input hints.

**The Team Identity Rule.** Team color is accompanied by one or two pips; TR and BR retain different silhouettes.

## Typography

Fredoka Semibold is bundled at `assets/Fredoka-Semibold.ttf` and explicitly loaded by the menu and HUD. The title uses the display role; score and clock sizes emphasize numbers. Buttons and context prompts share the button size. Input hints use the hint role.

Other current menu sizes range from 16 to 48 canvas units according to hierarchy. They are contextual labels, not an additional global type scale. Online LineEdit controls currently use Godot defaults and are not part of the documented type system.

## Layout

The base viewport is 1280 by 720 with `canvas_items` stretching. This is a PC game canvas with no mobile breakpoint or page grid.

Menus use a centered vertical stack with the menu-gap separation. Buttons have a minimum width and height defined above, with horizontal button-inset content margins. Scores sit 28 units from each side and 24 from the top; the clock shares the top inset. The cargo surface sits 28 from the left and bottom. Objective pictograms occupy the lower right and input hints run near the lower center.

Action prompts project from the current world target. They are not a fixed navigation bar. Menus overlay a light purple translucent shade while the arena remains visible.

## Elevation & Depth

HUD tiles use a diffuse shadow of radius 8 and offset (0, 3), tinted dark purple at 15% opacity. Normal buttons use radius 8 and offset (0, 4), at 16% opacity. Hover lightens the button fill by 12%; focus draws a 3-unit ink outline with a transparent fill.

The 3D arena uses a directional light with shadows, warm ambient light and matte surfaces. Robot and object materials use roughness 0.72; the CAD field material uses 0.82. The plinth, field height and object shadows establish depth.

## Shapes

Capsules form robot shells and arms, spheres form team pips and Mustika, and rectangular blocks retain clear faces. Dark faceplates and two cream eyes give the robot front an obvious direction. TR has a rear tray and forward arms; BR has tall cream uprights.

Tile and button corners share the tile radius. The action prompt is a 58-unit circular tile. Cargo slots are circular wells with a selection arc; objective towers are drawn from stacked rectangles.

## Components

### Buttons

Cream is the standard action fill and gold marks the initial play or replay action. All variants use ink text. Hover lightens the fill, focus adds the ink outline, and normal state carries the soft shadow. The information button uses an SVG icon.

### Score and clock

Score tiles carry white numerals and one or two white team pips. The centered cream clock carries ink numerals; free practice replaces the time with a short mode label.

### Cargo and action indicators

The cream cargo tile shows the active role and circular inventory slots. Held blocks use their team color, Mustika uses gold, and the selected item gets an ink arc. A white torus with a dark edge marks the actionable world target, paired with a cream input prompt. A cream progress arc indicates an operation underway.

### Motion

Movement leans the robot shell and adds a small vertical oscillation. Item transitions briefly scale to (1.14, 0.86, 1.14), then settle exponentially. Sky Block face changes rotate the visible object. These are presentation changes; gameplay state remains authoritative. Menus do not add ornamental motion.

## Do's and Don'ts

### Do:
- Do preserve the field geometry when changing surface color or lighting.
- Do pair team color with pips and role silhouettes.
- Do keep shell lean, bounce and squash separate from gameplay position.
- Do use short labels and drawn pictograms for immediate actions.

### Don't:
- Don't introduce a dashboard or prose panels into the play HUD.
- Don't replace block identity or team signals with decorative color.
- Don't treat room-code fields as a reusable visual style.
