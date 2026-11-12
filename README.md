# nixpkgs-bin

[![CI](https://github.com/ctran/nixpkgs-bin/actions/workflows/ci.yml/badge.svg)](https://github.com/ctran/nixpkgs-bin/actions/workflows/ci.yml)
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

Intel Macs (`x86_64-darwin`) are not supported.

Linux uses statically linked musl binaries.

## Installation

```bash
nix profile add github:ctran/nixpkgs-bin#mise   # one tool
nix profile add github:ctran/nixpkgs-bin#all    # every tool in the flake
nix run github:ctran/nixpkgs-bin#mise -- --version
```

`#default` is `#all`. To work from a local checkout:

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

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the repository layout, the source
file format, how to add a tool, and how updates work (manual and the daily
GitHub Actions workflow).

## Security

See [SECURITY.md](SECURITY.md) for how binaries are verified, what the hashes
do and don't guarantee, and how to report a vulnerability.

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
