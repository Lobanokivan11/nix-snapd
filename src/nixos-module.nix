self:

{
  pkgs,
  config,
  lib,
  ...
}:

let
  cfg = config.services.snap;
  snap = self.packages.${pkgs.stdenv.system}.default;
in
{
  options.services.snap = {
    enable = lib.mkEnableOption "snap service";

    snapBinInPath = lib.mkOption {
      default = true;
      example = false;
      description = "Include /var/lib/snapd/snap/bin in PATH.";
      type = lib.types.bool;
    };

    desktopFiles = lib.mkOption {
      default = true;
      example = false;
      description = "Add desktop files for opening snaps in desktop environments.";
      type = lib.types.bool;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ snap ];
    services.dbus.packages = [ snap ];
    security.apparmor.enable = true;
    systemd.tmpfiles.rules = [
      "d /var/lib/snapd 0755 root root -"
      "d /var/snap 0755 root root -"
      "L+ /snap - - - - /var/lib/snapd/snap"
    ];
    environment.extraInit = ''
      ${lib.optionalString cfg.snapBinInPath ''
        export PATH="/var/lib/snapd/snap/bin:$PATH"
      ''}

      ${lib.optionalString cfg.desktopFiles ''
        export XDG_DATA_DIRS="/var/lib/snapd/desktop:$XDG_DATA_DIRS"
      ''}
    '';

    systemd = {
      packages = [ snap ];
      sockets.snapd.wantedBy = [ "sockets.target" ];
      services.snapd.wantedBy = [ "multi-user.target" ];
      services.snapd.path = with pkgs; [
        snap
        util-linux
        kmod
        squashfsTools
      ];
    };

    security.wrappers.snap-confine-setuid-wrapper = {
      setuid = true;
      owner = "root";
      group = "root";
      source = "${snap}/libexec/snapd/snap-confine-stage-1";
    };
  };
}
