{
  config,
  lib,
  ...
}: let
  cfg = config.services.kvmd;
in {
  config = lib.mkIf cfg.enable {
    users.groups.kvmd = {};
    users.users.kvmd = {
      isSystemUser = true;
      group = "kvmd";
      description = "PiKVM - The main daemon";
      extraGroups = ["video" "dialout" "gpio" "systemd-journal" "kvmd-media" "kvmd-pst"];
    };

    systemd.services.kvmd = {
      description = "PiKVM - The main daemon";
      wantedBy = ["multi-user.target"];
      after = ["network.target" "network-online.target" "nss-lookup.target"];
      wants = ["network-online.target"];
      unitConfig.RequiresMountsFor = ["/var/lib/kvmd/msd" "/var/lib/kvmd/pst"];
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = 3;
        User = "kvmd";
        Group = "kvmd";
        AmbientCapabilities = "CAP_NET_RAW";
        ExecStart = "${lib.getExe cfg.package} --run";
        TimeoutStopSec = 10;
        KillMode = "mixed";
      };
    };
  };
}
