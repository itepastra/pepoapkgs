{
  btop,
  ...
}@args:
(btop.override (builtins.removeAttrs args [ "btop" ])).overrideAttrs (oldAttrs: {
  patches = (oldAttrs.patches or [ ]) ++ [ ./btop-no-nix-store.patch ];
})
