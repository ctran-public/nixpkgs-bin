# Development Environment Setup

This repository uses Nix with flakes for reproducible development environments.

## Using in Codespaces

When you open this repository in GitHub Codespaces, Nix will be automatically installed and configured.

## Local Development

To set up locally, ensure you have Nix installed with flakes support:

```bash
# Enter the Nix development environment
nix flake show

# Build all packages
nix build

# Run checks
nix flake check

# Enter a development shell (if devShell is defined in flake.nix)
nix develop
```

## Available Commands

Once Nix is set up, you can:

- **View available packages**: `nix flake show`
- **Build a specific package**: `nix build .#<package-name>`
- **Run all checks**: `nix flake check`
- **Build all packages**: `nix build`

## VS Code Extensions

The devcontainer automatically installs:
- **nix-ide** - Nix language support and linting
- **GitHub Copilot** - AI-assisted coding

Enable the Nix language server in VS Code settings for better editor support:
```json
{
  "nix.enableLanguageServer": true
}
```
