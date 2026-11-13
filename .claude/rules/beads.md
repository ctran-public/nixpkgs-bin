# Beads

This project uses `bd` (beads) for issue tracking. Run `bd prime` for the full workflow and command reference.

- Use `bd` for task tracking. Do not use TodoWrite, TaskCreate, or markdown TODO lists.
- Common commands: `bd ready`, `bd show <id>`, `bd update <id> --claim`, `bd close <id>`.
- Use `bd remember` for persistent knowledge instead of MEMORY.md files.
- Issues live in a local Dolt database; `.beads/issues.jsonl` is a passive export.
- Do not push, pull, or clean up stashes and branches unless the user asks.
