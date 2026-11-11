# Contributing

## Repository layout

```text
nixpkgs-bin/
├── flake.nix                 # outputs: packages, overlays.default, checks
├── flake.lock                # pins nixpkgs
├── nix/prebuilt.nix          # generic builder for one prebuilt release binary
├── sources/
│   └── mise.json             # per-tool data: repo, version, assets, hashes
├── scripts/update.sh         # bump sources/*.json to a release
└── .github/workflows/update.yml
```

`flake.nix` creates one package per `sources/*.json` file, named after the
file, for each system the file lists.

## Source files

```json
{
  "repo": "jdx/mise",
  "description": "Dev tools, env vars and task runner",
  "homepage": "https://mise.jdx.dev",
  "license": "mit",
  "mainProgram": "mise",
  "tag": "v{version}",
  "asset": "mise-v{version}-{platform}",
  "checksums": "SHASUMS256.txt",
  "version": "2026.11.2",
  "platforms": {
    "aarch64-darwin": { "platform": "macos-arm64", "hash": "sha256-…" }
  }
}
```

| Field | Meaning |
|---|---|
| `repo` | GitHub `owner/name` the release comes from |
| `tag`, `asset` | Templates for the release tag and the asset filename. `{version}` and `{platform}` are substituted. |
| `checksums` | Optional checksum file in the release (`sha256  filename` lines). Without it, the updater downloads and hashes each asset. |
| `platforms.<system>.platform` | What `{platform}` becomes for that Nix system |
| `platforms.<system>.hash` | SRI hash of the asset. The updater fills it in; leave `""` for a new tool. |
| `mainProgram` | Name of the installed binary (default: the file name) |
| `wrapperEnvironment` | Environment variables set by a wrapper script (optional; only affects variables the binary supports) |
| `license` | An attribute of `lib.licenses` (default: `unfree`) |
| `description`, `homepage` | Package metadata (optional) |

The builder only handles release assets that are **a bare executable**.
Tarballs and zips aren't supported yet.

## Adding a tool

1. Create `sources/<name>.json` with the fields above and empty hashes.
2. Run `scripts/update.sh <name>` to fill in the latest version and hashes.
3. Run `nix build .#<name>` and `./result/bin/<binary> --version`.

## Updating

### Manually

```bash
scripts/update.sh                 # every tool, latest release
scripts/update.sh mise            # one tool, latest release
scripts/update.sh mise 2026.11.1  # pin a version
```

The script needs `bash`, `curl`, `jq`, `xxd` and `base64`. It doesn't need
Nix, and it does nothing if a tool is already up to date. Then:

```bash
nix flake check
nix build .#mise && ./result/bin/mise --version
```

### GitHub Actions

`.github/workflows/update.yml` runs daily at 06:00 UTC, and you can also start
it by hand from the Actions tab, optionally picking a tool and version. For
each tool it:

1. Runs `scripts/update.sh <tool>`.
2. If anything changed, installs Nix, builds `.#<tool>` on x86_64-linux and runs `--version`.
3. Opens or updates a PR on the `update/<tool>` branch.

To let the workflow open PRs, enable **Settings → Actions → General → Allow
GitHub Actions to create and approve pull requests**. PRs opened with the
built-in `GITHUB_TOKEN` don't trigger other workflows; use a PAT or GitHub App
token if you add CI that must run on them.

### Why not use the `/latest` download URL?

Nix verifies downloads against fixed hashes, and a "latest" URL serves
different bytes after each release. Pinning both the version and the hash
keeps installs reproducible.

## Conventions

- Use conventional commit format (`feat:`, `fix:`, `ci:`, `docs:`, `chore:`)
  for commit messages and PR titles.
- Versions and hashes must change together, and sources must be pinned.
- Workflows: pin action versions, use minimal permissions, and add new jobs to
  the `ci/required` needs list.
