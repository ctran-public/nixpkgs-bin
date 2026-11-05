# nixpkgs-bin

[![Update tools](https://github.com/ctran/nixpkgs-bin/actions/workflows/update.yml/badge.svg)](https://github.com/ctran/nixpkgs-bin/actions/workflows/update.yml)

Prebuilt upstream binaries packaged for Nix. This is a small personal package
set, not an official NixOS project and not part of nixpkgs.

Each tool is installed straight from its **official prebuilt binaries** on
GitHub Releases instead of being built from source. It currently ships
[mise](https://mise.jdx.dev/), as an alternative to `nixpkgs#mise`.

- **Prebuilt binaries** — no Rust (or any) toolchain needed.
- **Pinned and verified** — every binary has a fixed version and SHA-256 hash.
- **Multi-tool** — one `sources/<name>.json` per tool; one generic builder.
- **Overlay included** — use `pkgs.mise` in NixOS / Home Manager / devShells.
- **Automated updates** — a GitHub Actions workflow opens a PR per new release.

## Requirements

Nix with the `nix-command` and `flakes` features enabled:

```bash
mkdir -p ~/.config/nix
echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
```

## Supported platforms

| Nix system | mise release binary | Flake `packages` | Overlay |
|---|---|---|---|
| `aarch64-darwin` | `macos-arm64` | yes | yes |
| `aarch64-linux` | `linux-arm64-musl` | yes | yes |
| `x86_64-linux` | `linux-x64-musl` | yes | yes |
| `x86_64-darwin` | `macos-x64` | no¹ | yes |

¹ nixpkgs-unstable (26.11) no longer evaluates `x86_64-darwin`, so the flake
doesn't expose packages for it. Intel Macs can apply `overlays.default` to a
nixpkgs that still supports them, such as `nixpkgs-26.05-darwin`; the hashes
are kept in `sources/mise.json`.

Linux uses statically linked musl binaries.

## Installation

```bash
nix profile add github:ctran/nixpkgs-bin#mise   # one tool
nix profile add github:ctran/nixpkgs-bin#all    # every tool in the flake
nix run github:ctran/nixpkgs-bin#mise -- --version
```

`#default` is mise. To work from a local checkout:

```bash
git clone https://github.com/ctran/nixpkgs-bin.git
cd nixpkgs-bin
nix profile add .#mise
```

Upgrade or remove:

```bash
nix profile upgrade --all
nix profile list
nix profile remove mise
```

> Installing mise through Nix doesn't activate it in your shell. See the
> [mise activation docs](https://mise.jdx.dev/getting-started.html).

## Using as a flake input

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-bin = {
      url = "github:ctran/nixpkgs-bin";
      inputs.nixpkgs.follows = "nixpkgs"; # avoid a second nixpkgs
    };
  };
}
```

**With the overlay** (recommended) — every tool becomes `pkgs.<name>` and
replaces the nixpkgs package of the same name:

```nix
nixpkgs.overlays = [ inputs.nixpkgs-bin.overlays.default ];   # NixOS / Home Manager
home.packages = [ pkgs.mise ];
```

**Without the overlay:**

```nix
home.packages = [ inputs.nixpkgs-bin.packages.${pkgs.stdenv.hostPlatform.system}.mise ];
```

**In a devShell:**

```nix
devShells.${system}.default = pkgs.mkShell {
  packages = [ inputs.nixpkgs-bin.packages.${system}.mise ];
};
```

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
| `license` | An attribute of `lib.licenses` (default: `unfree`) |
| `description`, `homepage` | Package metadata (optional) |

The builder only handles release assets that are **a bare executable**.
Tarballs and zips aren't supported yet.

### Adding a tool

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

## Security and reproducibility

- Every binary is checked against a pinned SHA-256 hash, taken from the
  upstream checksum file or computed from the downloaded asset.
- Versions are pinned in `sources/`, not resolved at evaluation time.
- `flake.lock` pins nixpkgs (only `fetchurl`, `stdenvNoCC` and `buildEnv` are used).
- The binary is copied into the store unmodified (no strip or patchelf), and no
  upstream install scripts run.
- A hash only proves the bytes match what was pinned. It doesn't prove who
  published them or that the binary is safe; you are trusting the upstream
  release.

## Limitations

- New releases need an update, either by hand or through the workflow's PR.
- CI builds only x86_64-linux; the hashes for other platforms come from the
  checksum file but aren't built in CI.
- Only single-executable release assets are supported.

## Comparison with nixpkgs

| | `nixpkgs#mise` | `nixpkgs-bin#mise` |
|---|---|---|
| Source | Built from source by nixpkgs | Official GitHub release binary |
| Needs a compiler if uncached | Yes (Rust) | No |
| Version | Whatever your nixpkgs revision has | Pinned here, updated daily |
| Reproducible | Yes | Yes |

## License

This flake repackages upstream binaries without modifying them. Each tool is
distributed under its own upstream license (mise: MIT, see
[jdx/mise](https://github.com/jdx/mise)). The license for this repository's
Nix code and docs is up to the maintainer.
