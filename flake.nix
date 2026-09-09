{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };
  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      # Supported systems for your flake packages, shell, etc.
      systems = [
        "aarch64-linux"
        # "i686-linux"
        "x86_64-linux"
        # "aarch64-darwin"
        # "x86_64-darwin"
      ];
      # This is a function that generates an attribute by calling a function you
      # pass to it, with each system as an argument
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      overlays = {
        additions = final: prev: import ./additions final;
        modifications = final: prev: import ./modifications prev;
      };

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        (import ./additions pkgs) // (import ./modifications pkgs)
      );

      nixosModules = import ./modules { inherit (nixpkgs) lib; };

      homeManagerModules = import ./hm-modules { inherit (nixpkgs) lib; };
    };
}
