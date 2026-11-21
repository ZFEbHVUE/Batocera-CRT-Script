# Python CRT Grid Tool

Grid Tool now uses Geometry's green Pygame menu, controller illustration, loading
frames and session-wide cursor hiding. Its function remains a native test-pattern
viewer for adjusting the CRT's own service menu. The before-you-start notice keeps
the original intro, then requires writing down original TV service-menu values
before any changes, lining the picture up to the grid in the service menu before
leaving, and using the Geometry Adjustment tool only for small software fine-tuning
afterward.

The resolution choices remain **640x480 at 60Hz** and **320x240 at 60Hz**. A opens
the selected grid or returns from it to the resolution menu. B closes a grid or
goes back one menu. Back/Select+Start exits the whole tool. Both Grid shell entry
points immediately exec Python; no terminal/dialog UI remains behind the grid.

## Controls

| Controller position | Keyboard event | Use |
| --- | --- | --- |
| D-pad / left stick | W/A/S/D | Choose in menus; ignored inside the grid |
| Xbox A, bottom | Enter | Select / return to the resolution menu |
| Xbox B, right | Escape | Back / close the grid |
| X/Y, shoulders, triggers | Tab | Switch between the two native patterns |
| Configured hotkey + Start | Ctrl+Q | Exit directly to EmulationStation |

D-pad/left-stick emit W/A/S/D because native arrows close the grid with Geometry
adjustment codes. The Python menu handles those navigation keys and the native
pattern viewer ignores them. Normal keyboard arrows still navigate menus and
close the native grid; Tab changes patterns.

Start alone is unused. Logical ES b maps to Xbox A/south and a to B/east; labels
on other controllers can differ. There is no picture-position/width adjustment
loop here: the CRT service menu controls those settings. Native keyboard arrows,
PageUp/Down, Delete and R return to the resolution menu rather than saving changes.

The native [Switchres grid source](https://github.com/antonioginer/switchres/blob/v2.2.2/grid.cpp)
supports Tab for pattern switching and includes Ctrl in its exit code. The exit
chord uses Ctrl+Q so the launcher can distinguish exiting the entire tool from
ordinary Escape/B returning to its menu, without changing native binaries or
adding a keyboard injector. The ROM-specific mapping overrides the global chord.

## Runtime

The fixed launch command selects one of the two resolutions using the active
`/etc/switchres.ini`, temporary mode switching and `/usr/bin/grid`. No keep-mode,
EDID-generation, configuration-write, overlay-save or reboot command is used.
Switchres restores the original display mode when the grid closes normally.
Native exit results are checked; failures display an error instead of success.

The Python window clears/closes during the native grid. Loading feedback appears
when it returns. Menu mouse events are blocked; the cursor-hide request remains
active through mode/window transitions and is released on exit. A nonblocking
runtime-switch lock prevents overlapping CRT display tools. No Geometry backup
or installer journal is created by Grid Tool itself.

Geometry.py accepts optional branding text for the shared renderer/cursor helper.
Geometry's defaults are unchanged: all nine default preview frames were compared
pixel-for-pixel with the accepted implementation. Its application engine,
calibration, backups, restore and controller mapping are unchanged.

Grid Tool depends on the companion Python Geometry UI and its geometry_ui_bridge
module. Apply the Grid add-on after the prepared Python Geometry PR, or use the
combined repository package. The earlier sealed Geometry PR ZIP is preserved.

Preview mode does not launch Switchres, acquire the runtime lock or open a system
log. For a pure preview from the script folder:

```sh
python3 -B grid_tool.py --preview menu
python3 -B grid_tool.py --preview gamepad
```

Normal diagnostics use `/userdata/system/logs/grid-tool.log`. No separate polling
observer is needed. Live hardware results and their exact scope are recorded in
the checkpoint's validation summary, separately from automated fixture results.
