{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.nwg-drawer;

  flags = {
    columns = "-c";
    debug = "-d";
    fileManager = "-fm";
    fsColumns = "-fscol";
    fsLenLimit = "-fslen";
    forceTheme = "-ft";
    gtkTheme = "-g";
    iconTheme = "-i";
    iconSize = "-is";
    keyboardMode = "-k";
    lang = "-lang";
    marginBottom = "-mb";
    marginLeft = "-ml";
    marginRight = "-mr";
    marginTop = "-mt";
    noCategories = "-nocats";
    noFileSearch = "-nofs";
    output = "-o";
    overlayLayer = "-ovl";
    pbExit = "-pbexit";
    pbLock = "-pblock";
    pbPoweroff = "-pbpoweroff";
    pbReboot = "-pbreboot";
    pbSize = "-pbsize";
    pbSleep = "-pbsleep";
    pbUseIconTheme = "-pbuseicontheme";
    resident = "-r";
    style = "-s";
    spacing = "-spacing";
    terminal = "-term";
    wm = "-wm";
  };

  # Build CLI args from cfg.settings (preserving declared key order).
  args = lib.concatLists (
    lib.mapAttrsToList (
      name: value:
      let
        flag = flags.${name} or "--${name}";
      in
      if builtins.isBool value then
        lib.optional value flag # e.g. --noactions
      else
        [
          flag
          (toString value)
        ]
    ) cfg.settings
  );

  drawerWrapper = pkgs.writeShellScriptBin "nwg-drawer" ''
    exec ${lib.getExe cfg.package} ${lib.concatStringsSep " " (map lib.escapeShellArg args)} "$@"
  '';
in
{
  options.programs.nwg-drawer = {
    enable = lib.mkEnableOption "nwg-drawer, a GTK application launcher for wlroots compositors";

    package = lib.mkPackageOption pkgs "nwg-drawer-rs" { };

    settings = lib.mkOption {
      default = { };
      description = ''
        Settings for nwg-drawer, these are translated to command-line flags passed to the binary.
        The options mirror upstream flags as documented in {command}`nwg-drawer --help`.
      '';
      type = lib.types.submodule {
        options = {
          columns = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = 6;
            description = "Number of Columns (-c)";
          };
          close = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Close drawer of existing instance (-close)";
          };
          closebtn = lib.mkOption {
            type = lib.types.enum [
              "left"
              "right"
              "none"
            ];
            default = "none";
            description = "Close button position (-closebtn)";
          };
          debug = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Turn on Debug messages (-d)";
          };
          fileManager = lib.mkOption {
            type = lib.types.str;
            default = "thunar";
            description = "File manager (-fm)";
          };
          fsColumns = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = 2;
            description = "File search result columns (-fscol)";
          };
          fsLength = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = 80;
            description = "File search name length limit (-fslen)";
          };
          forceTheme = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Force Theme for libadwaita apps, by adding 'GTK_THEME=<default-gtk-theme>' env var; ignored if wm argument == 'uwsm' (-ft)";
          };
          gtkThemeName = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "GTK theme name (-g)";
          };
          gtkIconThemeName = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "GTK icon theme name (-i)";
          };
          iconSize = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = 64;
            description = "Icon Size (-is)";
          };
          keyboardMode = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Set GTK layer shell keyboard interactivity to 'on-demand' mode (-k)";
          };
          language = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''force lang, e.g. "en", "pl" (-lang)'';
          };
          marginBottom = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            description = "Margin Bottom (-mb)";
          };
          marginLeft = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            description = "Margin Left (-ml)";
          };
          marginRight = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            description = "Margin Right (-mr)";
          };
          marginTop = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
            description = "Margin Top (-mt)";
          };
          noCategories = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Disable filtering by category (-nocats)";
          };
          noFileSearch = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Disable file search (-nofs)";
          };
          output = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Name of the output to display the drawer on (sway & Hyprland only) (-o)";
          };
          open = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Open drawer of existing instance (-open)";
          };
          overlayLayer = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Use overlay layer (-ovl)";
          };
          powerBarExit = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Command for the Exit power bar icon (-pbexit)";
          };
          powerBarLock = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Command for the Lock power bar icon (-pblock)";
          };
          powerBarPoweroff = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Command for the Poweroff power bar icon (-pbpoweroff)";
          };
          powerBarReboot = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Command for the Reboot power bar icon (-pbreboot)";
          };
          powerBarSleep = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Command for the Sleep power bar icon (-pbsleep)";
          };
          powerBarSize = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = 64;
            description = "Power bar icon size (only works w/ built-in icons) (-pbsize)";
          };
          powerBarUseIconTheme = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Use icon theme instead of built-in icons in power bar (-pbuseicontheme)";
          };
          resident = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Leave the program resident in memory (-r)";
          };
          style = lib.mkOption {
            type = lib.types.either lib.types.path lib.types.str;
            default = "drawer.css";
            description = "CSS file name or path for styling (-s)";
          };
          spacing = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = 20;
            description = "Icon spacing (-spacing)";
          };
          terminal = lib.mkOption {
            type = lib.types.str;
            default = "xterm-kitty";
            description = "Terminal emulator (-terminal)";
          };
          windowManager = lib.mkOption {
            type = lib.types.nullOr lib.types.enum [
              "sway"
              "hyprland"
              "river"
              "niri"
              "uwsm"
            ];
            default = null;
            description = "Use swaymsg exec (with 'sway' argument) or hyprctl dispatch exec (with 'hyprland') or riverctl spawn (with 'river') or niri msg action spawn -- (with 'niri') or uwsm app -- (with 'uwsm' for Universal Wayland Session Manager) to launch programs (-wm)";
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ drawerWrapper ];
  };
}
