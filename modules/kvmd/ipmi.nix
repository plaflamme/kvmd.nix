{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.kvmd;
  yaml = pkgs.formats.yaml {};
in {
  options.services.kvmd.ipmi = {
    enable = lib.mkEnableOption "the kvmd-ipmi server";
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open the IPMI port (UDP 623) in the firewall.";
    };
    passwordFile = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.configsDir}/kvmd/ipmipasswd";
      defaultText = lib.literalExpression "package example ipmipasswd";
      description = "kvmd-ipmi credentials file.";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.ipmi.enable) {
    warnings = lib.optional (cfg.ipmi.passwordFile == "${cfg.configsDir}/kvmd/ipmipasswd") ''
      services.kvmd.ipmi.passwordFile is the insecure upstream EXAMPLE; set it to your own.
    '';

    users.groups.kvmd-ipmi = {};
    users.users.kvmd-ipmi = {
      isSystemUser = true;
      group = "kvmd-ipmi";
      extraGroups = ["kvmd" "kvmd-selfauth"];
      description = "PiKVM - IPMI proxy";
    };

    environment.etc."kvmd/override.d/03-nixos-ipmi.yaml".source =
      yaml.generate "03-nixos-ipmi.yaml" {ipmi.auth.file = cfg.ipmi.passwordFile;};
    networking.firewall.allowedUDPPorts = lib.mkIf cfg.ipmi.openFirewall [623];

    systemd.services.kvmd-ipmi = {
      description = "PiKVM - IPMI to KVMD proxy";
      wantedBy = ["multi-user.target"];
      after = ["kvmd.service"];
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = 3;
        TimeoutStopSec = 3;
        User = "kvmd-ipmi";
        Group = "kvmd-ipmi";
        AmbientCapabilities = "CAP_NET_BIND_SERVICE";
        ExecStart = "${lib.getExe' cfg.package "kvmd-ipmi"} --run";
      };
    };
  };
}
