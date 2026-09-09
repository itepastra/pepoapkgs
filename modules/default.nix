{ lib, ... }:
lib.genAttrs (lib.attrnames (
  lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./.)
)) (name: import (./. + "/${name}"))
