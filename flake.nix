{
  description = "Prebuilt upstream binaries from GitHub Releases, packaged for Nix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      # x86_64-darwin is left out because nixpkgs-unstable (26.11) no longer
      # evaluates it. Intel Macs can still use `overlays.default` on a nixpkgs
      # that supports them (e.g. nixpkgs-26.05-darwin); the sources keep its hashes.
      systems = [ "aarch64-darwin" "aarch64-linux" "x86_64-linux" ];

      # One package per sources/<name>.json
      sources = lib.mapAttrs'
        (file: _: lib.nameValuePair
          (lib.removeSuffix ".json" file)
          (lib.importJSON ./sources/${file}))
        (lib.filterAttrs
          (file: type: type == "regular" && lib.hasSuffix ".json" file)
          (builtins.readDir ./sources));

      # All packages that have a binary for `system`, built with `pkgs`.
      # (The overlay passes prev's system so the attribute names don't depend
      # on `final`, which would recurse.)
      mkPackages = pkgs: system:
        lib.mapAttrs
          (pname: source: pkgs.callPackage ./nix/prebuilt.nix { inherit pname source; })
          (lib.filterAttrs (_: source: source.platforms ? ${system}) sources);

      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs:
        let
          tools = mkPackages pkgs pkgs.stdenv.hostPlatform.system;
          # Every tool in one profile entry: `nix profile add .#all`
          all = pkgs.buildEnv {
            name = "nixpkgs-bin-all";
            paths = builtins.attrValues tools;
          };
        in
        tools // {
          inherit all;
          default = all;
        });

      # Adds (or overrides) pkgs.<name> for each tool.
      overlays.default = final: prev: mkPackages final prev.stdenv.hostPlatform.system;

      # Every package builds, and its binary runs and reports its version.
      checks = forAllSystems (pkgs:
        let tools = mkPackages pkgs pkgs.stdenv.hostPlatform.system; in
        tools // lib.mapAttrs' (name: tool:
          lib.nameValuePair "${name}-version" tool.tests.version) tools);
    };
}
