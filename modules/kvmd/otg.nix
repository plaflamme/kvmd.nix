{
  config,
  lib,
  ...
}: let
  cfg = config.services.kvmd;
in {
  config = lib.mkIf cfg.enable {
    boot.kernelModules = ["libcomposite"];

    # kvmd-otg start/stop is not idempotent: a nixos-rebuild switch that
    # restarts it destroys HID/MSD until reboot. Boot-time fixture only.
    systemd.services.kvmd-otg = {
      description = "PiKVM - OTG setup";
      after = ["systemd-modules-load.service"];
      before = ["kvmd.service"];
      wantedBy = ["multi-user.target"];
      restartIfChanged = false;
      stopIfChanged = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${lib.getExe' cfg.package "kvmd-otg"} start";
        ExecStop = "${lib.getExe' cfg.package "kvmd-otg"} stop";
      };
    };
  };
}
