{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.kvmd;
in {
  config = lib.mkIf cfg.enable {
    users.groups.kvmd-pst = {};
    users.users.kvmd-pst = {
      isSystemUser = true;
      group = "kvmd-pst";
      extraGroups = ["kvmd"];
      description = "PiKVM - Persistent storage";
    };

    # kvmd locates PST storage by scanning /etc/fstab for the
    # X-kvmd.pst-user= option; persistent loop ext4.
    #
    # TODO: as with msd, prefer a bind mount (or user-supplied mount)
    # over creating a loop ext4 image; validate kvmd-pst remount on
    # hardware first (own follow-up PR).
    fileSystems."/var/lib/kvmd/pst" = {
      device = "/var/lib/kvmd/.pst.img";
      fsType = "ext4";
      options = ["loop" "nofail" "X-kvmd.pst-user=kvmd-pst" "X-kvmd.pst-group=kvmd-pst"];
    };

    systemd.tmpfiles.rules = ["d /var/lib/kvmd/pst 0775 kvmd-pst kvmd-pst -"];

    # kvmd-pst remounts this store rw/ro via a passwordless sudo helper.
    security.sudo.extraRules = [
      {
        users = ["kvmd-pst"];
        commands = [
          {
            command = lib.getExe' cfg.package "kvmd-helper-pst-remount";
            options = ["NOPASSWD"];
          }
        ];
      }
    ];

    systemd.services.kvmd-pst-image = {
      description = "PiKVM - create PST backing image";
      wantedBy = ["var-lib-kvmd-pst.mount"];
      before = ["var-lib-kvmd-pst.mount"];
      after = ["local-fs-pre.target"];
      unitConfig = {
        DefaultDependencies = false;
        RequiresMountsFor = ["/var/lib"];
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [pkgs.coreutils pkgs.e2fsprogs];
      script = ''
        mkdir -p /var/lib/kvmd
        if [ ! -e /var/lib/kvmd/.pst.img ]; then
          truncate -s 32M /var/lib/kvmd/.pst.img
          mkfs.ext4 -q -F /var/lib/kvmd/.pst.img
        fi
      '';
    };

    systemd.services.kvmd-pst = {
      description = "PiKVM - Persistent storage manager";
      wantedBy = ["multi-user.target"];
      before = ["kvmd.service"];
      unitConfig.RequiresMountsFor = ["/var/lib/kvmd/pst"];
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = 3;
        TimeoutStopSec = 5;
        User = "kvmd-pst";
        Group = "kvmd-pst";
        ExecStart = "${lib.getExe' cfg.package "kvmd-pst"} --run";
      };
    };
  };
}
