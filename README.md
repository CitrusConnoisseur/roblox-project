# roblox-project

Rojo + Luau project wired for VS Code, Luau LSP, StyLua, Selene and Continue.

## Daily loop

1. `code .` — open this folder.
2. Terminal 1: `rojo serve`
3. In Roblox Studio (Vinegar), open the **Rojo** plugin and click **Connect**.
4. Edit `.luau` files here; Studio updates live.

## Commands

```bash
rojo build -o build/game.rbxlx   # produce a place file
rojo sourcemap -o sourcemap.json # refresh Luau LSP types
stylua src                       # format
selene src                       # lint
```

## Quality gates

- **Pre-commit hook** — runs `stylua --check src` and `selene src` before every
  commit. Enable once per clone:

  ```bash
  git config core.hooksPath .githooks
  ```

- **CI** (`.github/workflows/ci.yml`) — on push/PR it checks formatting, lints,
  regenerates `sourcemap.json`, type-checks with `luau-lsp analyze` using real
  Roblox definitions, and builds the place.
- **Type-check locally** (optional, needs `luau-lsp` + Roblox definitions):

  ```bash
  rojo sourcemap -o sourcemap.json
  luau-lsp analyze --platform=roblox \
    --definitions=globalTypes.d.luau --sourcemap=sourcemap.json src
  ```

## Layout

```
src/client   -> StarterPlayer.StarterPlayerScripts
src/server   -> ServerScriptService
src/shared   -> ReplicatedStorage.Shared
```

`Main.client.luau` becomes a LocalScript, `Main.server.luau` a Script, and any
other `.luau` file a ModuleScript.
