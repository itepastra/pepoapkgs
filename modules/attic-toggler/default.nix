{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.services.attic-toggler;

  attic = inputs.attic.packages.${pkgs.stdenv.hostPlatform.system}.attic;

  # null -> "" (empty = disabled)
  prio = p: if p == null then "" else toString p;

  # The whole cache-switch logic, with every static value interpolated at
  # build time (no env vars left in the script).
  switch = pkgs.writeShellApplication {
    name = "attic-toggler";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      iproute2
      networkmanager
      systemd
    ];
    text = ''
      CONF=/etc/nix/nix.conf.d/10-attic.conf

      # VPN link administratively up?
      vpn_up() {
        ip link show ${lib.escapeShellArg cfg.vpnInterface} 2>/dev/null | grep -qw UP
      }

      # name of the connected wifi profile, empty if not on wifi
      wifi_ssid() {
        local dev
        dev=$(nmcli -t -f DEVICE,TYPE,STATE device \
              | awk -F: '$2=="wifi" && $3=="connected" { print $1; exit }')
        [ -n "$dev" ] || return 0
        nmcli -t -g GENERAL.CONNECTION device show "$dev"
      }

      # whitelisted SSIDs
      is_home_ssid() {
        local ssid="$1"
        for s in ${lib.concatMapStringsSep " " lib.escapeShellArg cfg.homeSsids}; do
          [ "$ssid" = "$s" ] && return 0
        done
        return 1
      }

      # Empty priority == substituter disabled. Lower number = higher
      # priority (cache.nixos.org is 40, so 10 wins and 99 loses).
      priority=""
    ''
    + (
      if cfg.force == true then
        ''
          priority=${toString cfg.homePriority}
        ''
      else if cfg.force == false then
        ''
          priority=""
        ''
      else
        ''
          if vpn_up; then
            ssid=$(wifi_ssid)
            if [ -z "$ssid" ] || is_home_ssid "$ssid"; then
              priority=${prio cfg.homePriority}     # wired or whitelisted wifi
            else
              priority=${prio cfg.foreignPriority}  # foreign wifi
            fi
          fi
        ''
    )
    + ''
      desired=""
      if [ -n "$priority" ]; then
        desired=$(cat <<EOF
      extra-substituters = ${cfg.substituter}?priority=$priority
      extra-trusted-public-keys = ${cfg.publicKey}
      extra-trusted-substituters = ${cfg.substituter}
      EOF
        )
      fi

      current=""
      [ -e "$CONF" ] && current=$(cat "$CONF")

      # Nothing to do -> don't touch the daemon.
      [ "$desired" = "$current" ] && exit 0

      if [ -n "$desired" ]; then
        install -d -m 0755 "$(dirname "$CONF")"
        printf '%s\n' "$desired" > "$CONF"
      else
        rm -f "$CONF"
      fi

      systemctl restart nix-daemon
    '';
  };
in
{
  options.services.attic-toggler = {
    enable = lib.mkEnableOption "attic substituter switching based on VPN/network state";

    substituter = lib.mkOption {
      type = lib.types.str;
      default = "http://trench.reef/anemone";
      description = "URL of the attic cache used as a substituter.";
    };
    publicKey = lib.mkOption {
      type = lib.types.str;
      default = "";
      example = "anemone:f/wBQ8yB5geTn96NjwRfbcoEvr8QuykN0iu0Rf2zUC8=";
      description = "Trusted public key for the substituter.";
    };
    endpoint = lib.mkOption {
      type = lib.types.str;
      default = "http://trench.reef";
      description = "attic server endpoint used by the client (for pushing).";
    };
    token = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "attic server token used by the client";
    };
    vpnInterface = lib.mkOption {
      type = lib.types.str;
      default = "reef0";
      description = "VPN interface that must be administratively up.";
    };
    homeSsids = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "niet-bestaand-netwerk" ];
      description = ''
        WiFi SSIDs treated as "home". Any other WiFi gets `foreignPriority`.
        Wired connections are always treated as home.
      '';
    };
    force = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Force the substituter on (`true`) or off (`false`), ignoring network
        state. `null` decides automatically from the VPN interface and SSID.
      '';
    };
    homePriority = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 10;
      description = "Substituter priority on the home network (lower = higher).";
    };
    foreignPriority = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.unsigned;
      default = 99;
      description = ''
        Priority on a non-whitelisted WiFi. Set to `null` to disable the
        substituter there instead of giving it a low priority.
      '';
    };

    watchStore = {
      enable = lib.mkEnableOption "attic watch-store auto-push of new store paths";
      server = lib.mkOption {
        type = lib.types.str;
        default = "trench";
        description = "attic server name.";
      };
      cache = lib.mkOption {
        type = lib.types.str;
        default = "anemone";
        description = "Cache to push new store paths to.";
      };
      ignoreUpstreamCacheFilter = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Pass --ignore-upstream-cache-filter (mirror everything).";
      };
    };
  };

  config = lib.mkIf cfg.enable {

    environment.systemPackages = [
      attic
      (pkgs.writeShellScriptBin "nix-build-push" ''
        name="$1"
        if [ -z "$name" ]; then
          echo "Usage: nix-build-push <nixosConfiguration name>"
          exit 1
        fi

        store_path=$(nix build -L --no-link --print-out-paths ".#nixosConfigurations.''${name}.config.system.build.toplevel")
        if [ $? -ne 0 ]; then
          echo "Build failed"
          exit 1
        fi

        echo "Built: $store_path"
        sudo attic push anemone "$store_path" --ignore-upstream-cache-filter

        drv=$(nix path-info --derivation "$store_path")
        requisites=$(nix-store --query --requisites --include-outputs "$drv")

        echo "$requisites" | sudo xargs attic push --ignore-upstream-cache-filter anemone
      '')
      (pkgs.writeShellScriptBin "nix-shell-push" ''
        if [ -z "$IN_NIX_SHELL" ] && [ -z "$name" ]; then
          echo "Not in a nix shell"
          exit 1
        fi

        paths=""
        for var in $buildInputs $nativeBuildInputs $propagatedBuildInputs $propagatedNativeBuildInputs; do
          paths="$paths $var"
        done

        if [ -z "$paths" ]; then
          echo "No build inputs found in environment"
          exit 1
        fi

        requisites=$(echo "$paths" | tr ' ' '\n' | grep -v '^$' | while read -r p; do
          drv=$(nix path-info --derivation "$p")
          if [ -n "$drv" ]; then
            nix-store --query --requisites --include-outputs "$drv"
          fi
        done)

        echo "$requisites" | sort -u | sudo xargs attic push --ignore-upstream-cache-filter anemone
      '')
      (pkgs.writeShellScriptBin "nix-push" ''
        requisites=""

        for name in "$@"; do
          # Build the derivation and get the output store path
          store_paths=$(NIXPKGS_ALLOW_UNFREE=1 nix build --no-link --print-out-paths --impure -L "$name")
          if [ -n "$store_paths" ]; then
            while IFS= read -r store_path; do
              reqs=$(nix-store --query --requisites "$store_path")
              requisites="$requisites"$'\n'"$reqs"
            done <<< "$store_paths"
          else
            echo "Warning: could not build '$name'" >&2
          fi
        done

        if [ -z "$requisites" ]; then
          echo "No requisites found, nothing to push." >&2
          exit 1
        fi

        echo "$requisites" | sort -u | xargs sudo attic push --ignore-upstream-cache-filter anemone
      '')
    ];

    systemd.tmpfiles.rules = [
      "C /root/.config/attic/config.toml 0600 root root - ${
        (pkgs.formats.toml { }).generate "attic-config.toml" {
          default-server = cfg.watchStore.server;
          servers.${cfg.watchStore.server} = {
            endpoint = cfg.endpoint;
            token-file = cfg.token;
          };
        }
      }"
      "d /etc/nix/nix.conf.d 0755 root root -"
    ];

    nix.extraOptions = ''
      !include /etc/nix/nix.conf.d/10-attic.conf
    '';

    # --- reconciler: runs at boot -------------------------------------------
    systemd.services.attic-toggler = {
      description = "Select the attic substituter based on VPN/network state";
      after = [ "NetworkManager.service" ];
      wants = [ "NetworkManager.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe switch;
      };
    };

    # --- re-run when the VPN interface comes up OR goes down ----------------
    systemd.services.attic-toggler-vpn = {
      description = "Re-evaluate attic substituter when ${cfg.vpnInterface} changes";
      bindsTo = [ "sys-subsystem-net-devices-${cfg.vpnInterface}.device" ];
      after = [ "sys-subsystem-net-devices-${cfg.vpnInterface}.device" ];
      wantedBy = [ "sys-subsystem-net-devices-${cfg.vpnInterface}.device" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${lib.getExe' pkgs.systemd "systemctl"} --no-block restart attic-toggler.service";
        ExecStopPost = "${lib.getExe' pkgs.systemd "systemctl"} --no-block restart attic-toggler.service";
      };
    };

    # --- re-run on NetworkManager events (wifi switches, NM VPNs) ------------
    networking.networkmanager.dispatcherScripts = [
      {
        type = "basic";
        source = pkgs.writeShellScript "attic-toggler-dispatch" ''
          case "$2" in
            up|down|vpn-up|vpn-down|connectivity-change)
              ${lib.getExe' pkgs.systemd "systemctl"} --no-block restart attic-toggler.service
              ;;
          esac
        '';
      }
    ];

    # --- auto-push new store paths, kept alive on crash ----------------------
    systemd.services.attic-toggler-watch-store = lib.mkIf cfg.watchStore.enable {
      description = "Push new Nix store paths to the attic cache";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "nix-daemon.service"
        "systemd-tmpfiles-setup.service"
      ];
      path = [ attic ];

      # Never stop retrying, even if it crash-loops.
      unitConfig.StartLimitIntervalSec = 0;

      serviceConfig = {
        Type = "simple";
        # Runs as root so it is a trusted user and can read
        # /root/.config/attic/config.toml.
        ExecStart =
          "${lib.getExe attic} watch-store "
          + "${cfg.watchStore.server}:${cfg.watchStore.cache}"
          + lib.optionalString cfg.watchStore.ignoreUpstreamCacheFilter " --ignore-upstream-cache-filter";

        # Crash / leak handling.
        Restart = "always";
        RestartSec = "5s";
        MemoryHigh = "1G";
        MemoryMax = "2G";
        RuntimeMaxSec = "24h";

        # Light hardening (kept permissive enough to read the store + config).
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "full";
        ProtectHome = false;
      };
    };
  };
}
