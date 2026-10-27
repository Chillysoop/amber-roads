# Amber Roads

A trade caravan game in the spirit of Vagrus: The Riven Realms, set in a gritty, Dinotopia-like frontier where sapient dinosaurs and humans share the Accord's toll roads. You lead a caravan across a hex overworld of cities, factions and scarcity. Fights resolve as autobattles built on Relay Company's combat simulation.

Design docs: [scoping](https://claude.ai/artifact/Pe5xPKE2Kmpev5gykUM5kh) and [vertical slice spec](https://claude.ai/artifact/64qqHBcaTnMpLx2tTpyjbc).

## Play

macOS or Linux:

```sh
./scripts/defold.sh run
```

The first run downloads the pinned Defold tools (Bob 1.13.2 and a Temurin 25 JDK, checksum-verified) into `.local-tools/`. Nothing is installed globally. On Windows, open `game/game.project` in the Defold 1.13.2 editor and press Build.

**Controls:** click a hex to plan a route and read its preview, then click it again or press Space to travel. R switches between the fastest route and preferring the Accord road. Esc cancels. Travel pauses when you spot a new place or run short of something.

## Tests

```sh
./scripts/defold.sh test            # all suites
./scripts/defold.sh test travel     # one suite
```

Tests run headless in the LuaJIT that ships inside Bob, so they match the engine.

## Layout

| Path | What it holds |
| --- | --- |
| `game/world/` | Pure Lua rules: hex math, terrain, the map, caravan upkeep, routes and travel. No engine calls. |
| `game/main/` | The Defold screen that draws the map and handles input. |
| `game/tests/` | Headless tests for everything in `world/`. |
| `scripts/defold.sh` | Project-local toolchain: test, build, bundle, run. |
