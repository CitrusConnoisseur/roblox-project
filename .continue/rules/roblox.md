---
name: Roblox Luau project rules
globs: ["**/*.luau", "**/*.lua"]
alwaysApply: true
description: Conventions for this Rojo + Luau project
---

# Roblox / Luau conventions

- Always write Luau with `--!strict` at the top of every file.
- Prefer `task.wait`, `task.spawn`, `task.delay` over the deprecated globals.
- Use `game:GetService("X")` at the top of files; never repeat it inline.
- Client code lives in `src/client`, server code in `src/server`, shared modules in `src/shared`.
- Shared modules return a table and must not touch `game.Players.LocalPlayer`.
- Validate every RemoteEvent/RemoteFunction argument on the server.
- Use `Instance.new("Thing")` plus explicit property assignment; set `Parent` last.
- Avoid `while true do` without a `task.wait`; prefer events and `task.spawn` for loops.
- Name things PascalCase for services/instances, camelCase for locals/functions.
- When unsure about a Roblox API, say so instead of inventing a method.
