# Agent instructions

- Never use emojis in any output (code, commits, PRs, chat).
- Be direct. No praise, filler, or restating the diff.
- Use conventional commit format for commit messages and PR titles.
- Nix: versions and hashes must change together; sources must be pinned.
- Workflows: pin action versions, use minimal permissions, and add new jobs to the `ci/required` needs list.
