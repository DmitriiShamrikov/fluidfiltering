
[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/B0B2SYRZW)

**Description**

This mod adds ability to set filter for pumps and fluid wagons, similar to inserters and cargo wagons.

**Features**

- All pumps can be set to work only with a specified fluid
- All fluid wagons can be set to accept only a specified fluid
- Pump filter can be set from circuit network similar to inserters
- Copy/paste is supported
- Blueprints are supported
- Undo is supported

**Compatibility**

Tested with Angel&Bob modpack, Space Exploration, Krastorio 2, Pyanodon. Basically all pumps and fluid wagons added by other mods should support filter feature.

**Known issues (mod API limitations)**

- Undo: when the game is paused in editor, filter settings are not restored with the entity. Workaround: unpause the game.
- Blueprints: when selecting new content for a bluprint in *library* filter settings are not copied. Workaround: move the blueprint to inventory first.
- Blueprints: when a blueprint is built over existing entities/ghosts filter settings from the blueprint are not applied.
