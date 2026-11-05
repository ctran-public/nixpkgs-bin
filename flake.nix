{
  description = "Mise prebuilt binary from GitHub Releases";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      version = "2026.11.1";

      platforms = {
        "aarch64-darwin" = "macos-arm64";
        "x86_64-darwin" = "macos-x64";
        "aarch64-linux" = "linux-arm64-musl";
        "x86_64-linux" = "linux-x64-musl";
      };

      # From SHASUMS256.txt of the GitHub release
      hashes = {
        "aarch64-darwin" = "sha256-nKEAWTD+2Q4PTDDZsT/kUw/ojQVJpxNJcWo6q5BRxic=";
        "x86_64-darwin" = "sha256-6tJBQlHo8pCcx1ZPirX9H+6mli7XfQF3d21y4IrnR6A=";
        "aarch64-linux" = "sha256-XOOAbxhaGgWo0M9tPro+Jla9ykbSK/hRh0pdn7iPLMI=";
        "x86_64-linux" = "sha256-6bRQRvWF8IWaaMxyp6qqjkRjnwtkhzcmIdvvk6vAIvs=";
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
