{
  description = "Mise prebuilt binary from GitHub Releases";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      version = "2026.11.2";

      platforms = {
        "aarch64-darwin" = "macos-arm64";
        "x86_64-darwin" = "macos-x64";
        "aarch64-linux" = "linux-arm64-musl";
        "x86_64-linux" = "linux-x64-musl";
      };

      # From SHASUMS256.txt of the GitHub release
      hashes = {
        "aarch64-darwin" = "sha256-kGhNE9kSXPIHxFsZ29vxm6+NXQ4+EBCfI2sbTQJ0FsA=";
        "x86_64-darwin" = "sha256-t9Eu9/+f1RhwSEueMv6HMDix8ZvV5Fg5GWvAeuc69yo=";
        "aarch64-linux" = "sha256-+QNrnNmfnKbfEwtgu0V9Ptp/vAnYwCQtxNgZ9EEKS5E=";
        "x86_64-linux" = "sha256-+k8Qr4PnExhUzuzfkJ/E5HF8i01OuSHPOEUdYfEY0mc=";
      };

      forAllSystems = f:
        nixpkgs.lib.genAttrs
          (builtins.attrNames platforms)
          (system: f system);

    in {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          platform = platforms.${system};

          binary = pkgs.fetchurl {
            url = "https://github.com/jdx/mise/releases/download/v${version}/mise-v${version}-${platform}";
            hash = hashes.${system};
          };
        in {
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

          default = self.packages.${system}.mise;
        }
      );
    };
}
