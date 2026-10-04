{ config, lib, pkgs, ... }: let
  cfg = config.programs.osu;
in {
  options.programs.osu = let
    inherit (lib.options) mkEnableOption mkOption;
    T = lib.types;
  in {
    enable = mkEnableOption "osu!, the free-to-win rhythm game";
    package = mkOption {
      type = T.package;
      default = pkgs.osu-lazer-bin.override { nativeWayland = cfg.nativeWayland; };
    };
    nativeWayland = mkOption {
      type = T.bool;
      default = false;
    };
    pipewireLatency = mkOption {
      type = T.str;
      default = "256/44100";
    };
  };
  config = lib.mkIf cfg.enable {
    home.packages = [
      (pkgs.symlinkJoin {
        name = "osu-lazer-bin-wrapped";
        paths = [ (cfg.package.override { nativeWayland = true; }) ];
        buildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/osu! \
            --set PIPEWIRE_LATENCY "${cfg.pipewireLatency}"
        '';
      })
    ];
  };
}
