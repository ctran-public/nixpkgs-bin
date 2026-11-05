# nix-mise

A lightweight Nix flake for installing [mise](https://mise.jdx.dev/) directly from its official GitHub release binaries.

Unlike the standard `nixpkgs#mise` package, this flake downloads and installs the **precompiled mise executable**, avoiding the need to compile Rust source code.

## Features

- **Prebuilt binaries** — Downloads official binaries from GitHub Releases.
- **Fast installation** — No Rust compilation required.
- **Cross-platform** — Supports macOS and Linux on ARM64 and x86-64.
- **Reproducible** — Pins release versions and SHA-256 checksums.
- **Nix profile integration** — Install and upgrade with standard Nix commands.
- **Automated updates** — Compatible with GitHub Actions for tracking new releases.
- **Minimal packaging** — Uses `stdenvNoCC` and `fetchurl`.

## Requirements

- Nix package manager with flakes and the `nix-command` feature enabled.
- Internet access to GitHub Releases for uncached binaries.
- A supported operating system and architecture.

Enable flakes if necessary:

```bash
mkdir -p ~/.config/nix
echo 'experimental-features = nix-command flakes' \
  >> ~/.config/nix/nix.conf
```

## Supported Platforms

| Nix System | GitHub Release Binary |
|---|---|
| `aarch64-darwin` | `macos-arm64` |
| `x86_64-darwin` | `macos-x64` |
| `aarch64-linux` | `linux-arm64-musl` |
| `x86_64-linux` | `linux-x64-musl` |

Linux uses statically linked musl binaries to minimize runtime library dependencies.

Platform support depends on the availability of corresponding binaries in the upstream release.

## Installation

### Install from GitHub

Once this flake is published to GitHub:

```bash
nix profile add github:YOUR_USERNAME/nix-mise#mise
```

Replace `YOUR_USERNAME` with your GitHub username or organization.

Verify the installation:

```bash
mise --version
```

### Install from a local checkout

Clone the repository:

```bash
git clone https://github.com/YOUR_USERNAME/nix-mise.git
cd nix-mise
```

Install:

```bash
nix profile add .#mise
```

Alternatively, run mise without permanently installing it:

```bash
nix run .#mise -- --version
```

### Run directly from GitHub

```bash
nix run github:YOUR_USERNAME/nix-mise#mise -- --version
```

## Usage

After installation, mise behaves like any other installation of the official binary.

Install Node.js:

```bash
mise use --global node@24
```

Install Python for a project:

```bash
mkdir my-project
cd my-project

mise use python@3.13
```

List installed tools:

```bash
mise ls
```

> **Note:** Installing mise through Nix does not automatically activate mise in your shell. Follow the [mise activation documentation](https://mise.jdx.dev/getting-started.html) to configure your shell.

## Repository Structure

```text
nix-mise/
├── flake.nix
├── flake.lock
├── README.md
└── .github/
    └── workflows/
        └── update.yml
```

- `flake.nix` — Defines mise binary packages for supported platforms.
- `flake.lock` — Pins the Nixpkgs dependency for reproducibility.
- `README.md` — Installation and maintenance documentation.
- `update.yml` — Optional GitHub Actions workflow for automated updates.

## Flake Configuration

The flake defines a `mise` package for each supported platform.

The package uses `fetchurl` to download the appropriate GitHub release executable and installs it into:

```text
$out/bin/mise
```

Example package definition:

```nix
mise = pkgs.stdenvNoCC.mkDerivation {
  pname = "mise";
  inherit version;

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 ${binary} $out/bin/mise

    runHook postInstall
  '';
};
```

No Rust toolchain is required to build this package.

### Release Version

The mise version is explicitly configured in `flake.nix`:

```nix
version = "2026.11.1";
```

Update this value when upgrading mise.

### SHA-256 Verification

Every downloaded executable must have a matching SHA-256 checksum.

Example:

```nix
hashes = {
  "aarch64-darwin" = "<SHA-256>";
  "x86_64-darwin" = "<SHA-256>";
  "aarch64-linux" = "<SHA-256>";
  "x86_64-linux" = "<SHA-256>";
};
```

Replace these placeholders with actual Nix SRI hashes before building.

Calculate a checksum using:

```bash
nix store prefetch-file --json \
  "https://github.com/jdx/mise/releases/download/v2026.11.1/mise-v2026.11.1-macos-arm64"
```

Copy the returned `hash` into the corresponding platform entry.

Each platform requires its own checksum. Do not reuse a checksum across different binaries.

## Updating mise

### Manual Update

1. Find the latest release at [mise GitHub Releases](https://github.com/jdx/mise/releases).
2. Update `version` in `flake.nix`.
3. Obtain the SHA-256 checksum for each supported binary.
4. Update the `hashes` attribute set.
5. Validate and build the flake.
6. Commit and push the changes.

Validate:

```bash
nix flake check
```

Build for your current platform:

```bash
nix build .#mise
```

Verify the packaged executable:

```bash
./result/bin/mise --version
```

Check the flake metadata:

```bash
nix flake show
```

### Automated Updates with GitHub Actions

The recommended approach is to use GitHub Actions to periodically check for new mise releases.

The updater should:

1. Query the GitHub Releases API for the latest stable release.
2. Compare it against the version in `flake.nix`.
3. Download or prefetch all supported binaries.
4. Calculate the Nix-compatible SHA-256 hashes.
5. Update `flake.nix`.
6. Validate the package definitions and build on available runners.
7. Create a pull request containing the updated version and hashes.

A suggested schedule is once per day.

This automation is optional and must be implemented separately.

**Why not use GitHub's `/latest` download URL directly?**

Nix uses fixed-output hashes to verify external downloads. When the upstream binary changes, its hash also changes.

Using an unpinned latest-release URL breaks the expected reproducibility of Nix packages.

Pinning both the version and checksum allows consumers to obtain the same binary consistently.

## Upgrading an Installed Package

After the repository has been updated, upgrade the installed profile package:

```bash
nix profile upgrade --all
```

For installations referencing an immutable commit, the source reference must first be updated to a newer revision.

Inspect installed profile packages:

```bash
nix profile list
```

## Uninstallation

List the profile entries:

```bash
nix profile list
```

Remove the appropriate mise entry using its profile identifier, for example:

```bash
nix profile remove mise
```

The exact identifier depends on the installed profile entry.

## Using with Other Nix Tools

### Home Manager

The package can be referenced as a flake input in a Home Manager configuration.

Example input:

```nix
inputs.mise-bin.url = "github:YOUR_USERNAME/nix-mise";
```

Include the package for the target system:

```nix
home.packages = [
  inputs.mise-bin.packages.${pkgs.stdenv.hostPlatform.system}.mise
];
```

Ensure `mise-bin` is available in the configuration's `inputs` scope.

### Development Shells

You can also include the binary package in a Nix development shell:

```nix
devShells.${system}.default = pkgs.mkShell {
  packages = [
    self.packages.${system}.mise
  ];
};
```

This exposes the mise executable within the development shell without requiring a permanent profile installation.

### devenv

The same package can be used in a `devenv` environment when the custom flake is declared as an input.

This allows Nix to manage the mise executable while mise manages project-specific runtime versions.

## Security and Reproducibility

This flake follows several important principles:

**Binary integrity**

All downloaded binaries are validated against fixed SHA-256 hashes.

**Version pinning**

The mise release version is explicitly defined rather than resolved dynamically at build time.

**Dependency pinning**

The `flake.lock` file pins the Nixpkgs revision used to build the package.

**Upstream trust**

The executable comes directly from the official mise GitHub release. SHA-256 verification confirms that downloaded bytes match the pinned hash; it does not independently establish the publisher's identity or guarantee that the binary is free of vulnerabilities.

**No build-time installation scripts**

The derivation copies a downloaded executable into the Nix store instead of running an upstream installation script.

**Immutable package storage**

Nix stores the installed executable under `/nix/store`, preventing ordinary modifications to the packaged binary.

## Limitations

- A new upstream release requires updating the pinned version and hashes.
- The flake does not automatically discover the latest version at Nix evaluation time.
- Fixed hashes must match the exact binary assets.
- Cross-platform builds may require appropriate builders or runners.
- GitHub Actions update automation is not included in the basic flake.
- Runtime behavior and compatibility still depend on the upstream mise executable.
- `nix flake check` does not guarantee that every supported platform has been built and tested.

## Comparison with Nixpkgs

| Feature | `nixpkgs#mise` | `nix-mise#mise` |
|---|---|---|
| Source | Nixpkgs derivation | Official GitHub binary |
| Rust compilation | May build from source if not cached | Not required |
| Binary cache | Supported | Supported if configured |
| Version | Determined by Nixpkgs revision | Explicitly pinned |
| Checksums | Managed by Nixpkgs | Managed by this flake |
| GitHub release tracking | Depends on Nixpkgs updates | Can be automated independently |
| Nix profile support | Yes | Yes |
| Reproducible | Yes | Yes, with pinned inputs |

## Related Projects

- [mise](https://mise.jdx.dev/) — Development tool and runtime version manager.
- [mise GitHub Repository](https://github.com/jdx/mise) — Source code and official releases.
- [Nix](https://nixos.org/) — Declarative package manager and build system.
- [Nix Flakes](https://nix.dev/concepts/flakes) — Reproducible Nix configuration mechanism.
- [Home Manager](https://github.com/nix-community/home-manager) — Declarative user environment management.
- [devenv](https://devenv.sh/) — Reproducible development environments.

## License

This flake packages the upstream mise binary without modifying its source code.

Mise is distributed under its own upstream license. Refer to the [official mise repository](https://github.com/jdx/mise) for licensing information.

The license for this flake's configuration and documentation should be specified separately by the repository maintainer.

