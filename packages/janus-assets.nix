{
  runCommand,
  fetchurl,
  janus-gateway,
  pikvm-packages,
}: let
  webrtcAdapter = fetchurl {
    url = "https://raw.githubusercontent.com/webrtcHacks/adapter/v9.0.1/release/adapter.js";
    hash = "sha256-qJ4ou0JzcZYb0z+094G11tQBAHOuYgP5G2qTTyYvzDw=";
  };
in
  runCommand "janus-assets" {
    pname = "janus-assets";
    inherit (janus-gateway) version;
    passthru.skipAutoUpdate = true;
  } ''
    mkdir -p $out
    cp ${janus-gateway.src}/html/demos/janus.js $out/janus.js
    cp ${webrtcAdapter} $out/adapter.js
    chmod +w $out/janus.js
    patch $out/janus.js < ${pikvm-packages}/packages/janus-gateway-pikvm/0001-js.patch
  ''
