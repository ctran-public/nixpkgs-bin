# Security policy

## Security and reproducibility

- Every binary is checked against a pinned SHA-256 hash, taken from the
  upstream checksum file or computed from the downloaded asset.
- Versions are pinned in `sources/`, not resolved at evaluation time.
- `flake.lock` pins the nixpkgs revision used to evaluate and build the flake.
- The binary is copied into the store unmodified (no strip or patchelf), and no
  upstream install scripts run.
- A hash only proves the bytes match what was pinned. It doesn't prove who
  published them or that the binary is safe; you are trusting the upstream
  release.

## Reporting a vulnerability

Report problems with this repository (the Nix code, update script or
workflows) through
[private vulnerability reporting](https://github.com/ctran/nixpkgs-bin/security/advisories/new)
rather than a public issue. Vulnerabilities in a packaged tool should be
reported to that tool's upstream project.
