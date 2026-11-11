# Package a single prebuilt executable from a GitHub release, described by
# a sources/<name>.json file.
{ lib, stdenvNoCC, fetchurl, testers, makeWrapper, pname, source }:

let
  system = stdenvNoCC.hostPlatform.system;
  target = source.platforms.${system}
    or (throw "${pname}: no prebuilt binary for ${system}");

  fill = builtins.replaceStrings
    [ "{version}" "{platform}" ]
    [ source.version target.platform ];

  tag = fill source.tag;
  asset = fill source.asset;
  mainProgram = source.mainProgram or pname;
in
stdenvNoCC.mkDerivation (finalAttrs: {
  inherit pname;
  inherit (source) version;

  src = fetchurl {
    url = "https://github.com/${source.repo}/releases/download/${tag}/${asset}";
    inherit (target) hash;
  };

  dontUnpack = true;
  # Upstream binaries are used as-is.
  dontStrip = true;
  dontPatchELF = true;

  nativeBuildInputs = lib.optional ((source.wrapperEnvironment or {}) != {}) makeWrapper;

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/${mainProgram}"
    runHook postInstall
  '';

  postInstall = lib.optionalString ((source.wrapperEnvironment or {}) != {}) ''
    wrapProgram "$out/bin/${mainProgram}" ${
      lib.concatStringsSep " " (lib.mapAttrsToList
        (name: value: "--set ${lib.escapeShellArg name} ${lib.escapeShellArg value}")
        source.wrapperEnvironment)
    }
  '';

  # The binary runs and reports the packaged version.
  passthru.tests.version = testers.testVersion {
    package = finalAttrs.finalPackage;
    command = "${mainProgram} ${source.versionArg or "--version"}";
  };

  meta = {
    description = source.description or pname;
    homepage = source.homepage or "https://github.com/${source.repo}";
    changelog = "https://github.com/${source.repo}/releases/tag/${tag}";
    license = lib.licenses.${source.license} or lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = builtins.attrNames source.platforms;
    inherit mainProgram;
  };
})
