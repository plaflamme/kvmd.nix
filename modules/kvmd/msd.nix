{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.kvmd;
  yaml = pkgs.formats.yaml {};
in {
  options.services.kvmd.msd = {
    enable = lib.mkEnableOption "USB Mass Storage Device emulation";
    imageSize = lib.mkOption {
      type = lib.types.str;
      default = "4G";
      description = "Size of the persistent ext4 image backing the MSD store (/var/lib/kvmd/msd).";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    (lib.mkIf cfg.msd.enable {
      # TODO: this loop ext4 image is a PiKVM carryover (read-only root).
      # On NixOS prefer a bind mount or a user-supplied mount; needs
      # hardware validation of the otgmsd remount + f_mass_storage path.
      # kvmd locates the store by scanning fstab for X-kvmd.otgmsd-user=.
      fileSystems."/var/lib/kvmd/msd" = {
        device = "/var/lib/kvmd/.msd.img";
        fsType = "ext4";
        options = ["loop" "nofail" "X-kvmd.otgmsd-user=kvmd"];
      };

      systemd.tmpfiles.rules = ["d /var/lib/kvmd/msd 0755 kvmd kvmd -"];

      # kvmd's MSD plugin (user kvmd) remounts this store rw/ro via a
      # passwordless sudo helper; without it media insert/eject fails.
      security.sudo.extraRules = [
        {
          users = ["kvmd"];
          commands = [
            {
              command = lib.getExe' cfg.package "kvmd-helper-otgmsd-remount";
              options = ["NOPASSWD"];
            }
          ];
        }
      ];

      systemd.services.kvmd-msd-image = {
        description = "PiKVM - create MSD backing image";
        wantedBy = ["var-lib-kvmd-msd.mount"];
        before = ["var-lib-kvmd-msd.mount"];
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
          if [ ! -e /var/lib/kvmd/.msd.img ]; then
            truncate -s ${cfg.msd.imageSize} /var/lib/kvmd/.msd.img
            mkfs.ext4 -q -F /var/lib/kvmd/.msd.img
          fi
        '';
      };
    })
    (lib.mkIf (!cfg.msd.enable) {
      # Without msd, neutralise the main config's msd.type=otg so kvmd-otg
      # does not abort (f_mass_storage needs PiKVM's kernel patch).
      environment.etc."kvmd/override.d/01-nixos-disable-msd.yaml".source =
        yaml.generate "01-nixos-disable-msd.yaml" {kvmd.msd.type = "disabled";};
    })
  ]);
}
