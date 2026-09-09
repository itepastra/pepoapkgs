pkgs:
let
  packageNames =
    let
      entries = builtins.readDir ./.;
    in
    builtins.filter (name: entries.${name} == "directory") (builtins.attrNames entries);

  extraAttrs = {
    btop = {
      btop = pkgs.btop;
    };
  };
in
builtins.listToAttrs (
  builtins.map (name: {
    inherit name;
    value = pkgs.callPackage (./. + "/${name}") (extraAttrs.${name} or { });
  }) packageNames
)
