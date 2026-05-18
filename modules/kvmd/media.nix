{
  config,
  lib,
  ...
}: let
  cfg = config.services.kvmd;
in {
  config = lib.mkIf cfg.enable {
    users.groups.kvmd-media = {};
    users.users.kvmd-media = {
      isSystemUser = true;
      group = "kvmd-media";
      extraGroups = ["kvmd"];
      description = "PiKVM - The media proxy";
    };

    systemd.services.kvmd-media = {
      description = "PiKVM - Media proxy server";
      wantedBy = ["multi-user.target"];
      after = ["kvmd.service"];
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = 3;
        TimeoutStopSec = 3;
        User = "kvmd-media";
        Group = "kvmd-media";
        ExecStart = "${lib.getExe' cfg.package "kvmd-media"} --run";
      };
    };
  };
}
