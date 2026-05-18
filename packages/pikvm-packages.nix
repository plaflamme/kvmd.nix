{
  stdenvNoCC,
  fetchFromGitHub,
  nix-update-script,
}:
stdenvNoCC.mkDerivation {
  pname = "pikvm-packages";
  version = "0-unstable-2026-05-02";

  src = fetchFromGitHub {
    owner = "pikvm";
    repo = "packages";
    rev = "0a17564262abfd5d7127a735b13931ffad16b6c0";
    hash = "sha256-MBO947FddkTSEUqX5xaL9Pl4ZXNSW+i0phS86gGLjFs=";
  };

  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    cp -a . "$out"
    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {extraArgs = ["--flake" "--version=branch"];};
}
