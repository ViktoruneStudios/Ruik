# E.B.U.R.P. for Godot

A port of the E.B.U.R.P. engine and its demo game from CoffeeScript/HTML5 to
Godot 4 (GDScript). It plays the same game: the same data file, maps, art,
sounds, rules, combat AI and nine-button interface.

## Running

1. Install Godot 4.3 or newer (the standard build; C# is not needed).
2. In the Project Manager, choose **Import** and pick `godot/project.godot`.
3. Press **F5** (Run Project). The first open imports the art and audio.

Controls are the same as the web version. Click the buttons or use the keyboard:

```
Q W E        numpad 7 8 9
A S D   or   numpad 4 5 6
Z X C        numpad 1 2 3
```

Arrow keys move, and Enter presses the center button. In debug builds, `G`
and `H` are the original debug hooks: `G` wins a combat instantly.

## Project layout

| Path | Contents |
| --- | --- |
| `data/gurkDemo.js` | The game data, unchanged from `game/gurkDemo.js`, documented inline. |
| `data/maps/*.txt` | Map files, referenced from the data as `"@name.txt"`. |
| `data/icons.js` | Icon name to atlas position, from `web/icons.js`. |
| `assets/images` | The 1x art: icon atlases, fonts, buttons, screen overlays. |
| `assets/sounds`, `assets/music` | Sound effects (wav) and music (ogg). |
| `scripts/core` | Engine: data loader, screen, fonts, buttons, base views, image effects. |
| `scripts/model` | Items, creatures, heroes, and the game state. |
| `scripts/adventure` | Every non-combat screen: title, hero creation, map, party, items, spells. |
| `scripts/combat` | Combat view, combatants, and the enemy AI. |
| `scripts/gurk.gd` | Entry point: view stack, input, sound, music, timers. |

The CoffeeScript classes map one-to-one onto these scripts, with method names
in GDScript's snake_case (`processResult` became `process_result`). Fields read
straight from the game data keep their original camelCase keys.

## Editing the game

`data/gurkDemo.js` is read directly at startup, so edit it and the map files
the same way as before (see the comments in that file). `GameCompiler.java` is
no longer needed. The title screen's **CHECK** button runs the data validator
and prints any problems to Godot's Output panel.

These are copies of `game/gurkDemo.js`, `maps/` and `web/icons.js`. If you
change the originals, copy them over again.

New icons still have to go through `tools/gurk/ImageCompiler.java`, which
builds the icon atlases and `icons.js`. Copy its `icons0-1.png`,
`icons1-1.png` and `icons.js` into `assets/images/icons0.png`,
`assets/images/icons1.png` and `data/icons.js`.

## Tests

Two test scenes in `tests/` drive the game by pressing its buttons. Both back
up and restore your saved game and settings.

- `tests/smoke_test.tscn` makes a party, tours the menus, saves and reloads,
  fights 40 battles across the dungeons, then presses 6,000 random buttons at
  25x speed. Any problem shows up as `SCRIPT ERROR` in the output.

  ```
  godot --headless --path godot res://tests/smoke_test.tscn
  ```

- `tests/screenshots.tscn` opens a window and saves pictures of key screens
  to `user://screenshots/`.

Both were checked against Godot 4.7.2.

## Exporting

The data files are plain text, which Godot leaves out of exports by default.
In **Project > Export**, select the preset, open the **Resources** tab and add
`data/*` to **Filters to export non-resource files/folders**.

Saved games and settings go to Godot's `user://` folder (`saved_game.json`
and `settings.cfg`).

## Differences from the web version

- Rendering uses the 1x art in a 300x136 window, scaled up by whole multiples
  (3x by default), with the buttons beside the screen instead of below it.
- Sound and music start on. The web page started muted until you clicked "on".
- **CHECK** on the title screen also shows a confirmation, since there is no
  browser console.
- A few crashes in the original become no-ops: unknown icons, missing data
  fields, and casting or attacking when no target remains.
- The unused `Map`, `CreateView` and `Test` classes were not ported.
