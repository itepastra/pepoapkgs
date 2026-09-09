pkgs:
let
  packageNames =
    let
      entries = builtins.readDir ./.;
    in
    builtins.filter (name: entries.${name} == "directory") (builtins.attrNames entries);
in
builtins.listToAttrs (
  builtins.map (name: {
    inherit name;
    value = pkgs.callPackage (./. + "/${name}") { };
  }) packageNames
)
