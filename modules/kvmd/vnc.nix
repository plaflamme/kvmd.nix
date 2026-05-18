{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.kvmd;
  yaml = pkgs.formats.yaml {};
  userCerts = cfg.vnc.sslCertFile != null && cfg.vnc.sslKeyFile != null;
  vncSslDir = "/var/lib/kvmd/vnc-ssl";
  certPath =
    if userCerts
    then cfg.vnc.sslCertFile
    else "${vncSslDir}/server.crt";
  keyPath =
    if userCerts
    then cfg.vnc.sslKeyFile
    else "${vncSslDir}/server.key";
in {
  options.services.kvmd.vnc = {
    enable = lib.mkEnableOption "the kvmd-vnc server";
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open the VNC port (TCP 5900) in the firewall.";
    };
    passwordFile = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.configsDir}/kvmd/vncpasswd";
      defaultText = lib.literalExpression "package example vncpasswd";
      description = "kvmd-vnc credentials file.";
    };
    sslCertFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "TLS certificate for the VNC server (optional).";
    };
    sslKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "TLS key for the VNC server (optional).";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.vnc.enable) {
    warnings = lib.optional (cfg.vnc.passwordFile == "${cfg.configsDir}/kvmd/vncpasswd") ''
      services.kvmd.vnc.passwordFile is the insecure upstream EXAMPLE; set it to your own.
    '';

    users.groups.kvmd-vnc = {};
    users.users.kvmd-vnc = {
      isSystemUser = true;
      group = "kvmd-vnc";
      extraGroups = ["kvmd" "kvmd-selfauth"];
      description = "PiKVM - VNC proxy";
    };

    # kvmd-vnc defaults to VeNCrypt (TLS) on, so it needs an x509 cert.
    # Always point kvmd at the cert via an override (user-supplied path,
    # or the self-signed one we generate) rather than linking into /etc.
    environment.etc."kvmd/override.d/02-nixos-vnc.yaml".source = yaml.generate "02-nixos-vnc.yaml" {
      vnc = {
        auth.vncauth.file = cfg.vnc.passwordFile;
        server.tls.x509 = {
          cert = certPath;
          key = keyPath;
        };
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.vnc.openFirewall [5900];

    systemd.services.kvmd-vnc-certgen = lib.mkIf (!userCerts) {
      description = "PiKVM - Generate self-signed kvmd-vnc certificate";
      wantedBy = ["kvmd-vnc.service"];
      before = ["kvmd-vnc.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        if [ ! -e ${vncSslDir}/server.crt ]; then
          mkdir -p ${vncSslDir}
          ${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:2048 -nodes \
            -keyout ${vncSslDir}/server.key -out ${vncSslDir}/server.crt \
            -days 3650 -subj "/CN=${cfg.hostName}"
          chmod 640 ${vncSslDir}/server.key
          chgrp kvmd-vnc ${vncSslDir}/server.key ${vncSslDir}/server.crt || true
        fi
      '';
    };

    systemd.services.kvmd-vnc = {
      description = "PiKVM - VNC to KVMD/Streamer proxy";
      wantedBy = ["multi-user.target"];
      after = ["kvmd.service"];
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = 3;
        TimeoutStopSec = 3;
        User = "kvmd-vnc";
        Group = "kvmd-vnc";
        ExecStart = "${lib.getExe' cfg.package "kvmd-vnc"} --run";
      };
    };
  };
}
