{
  rustPlatform,
  fetchCrate,
  pkg-config,
  glib,
  pango,
  gdk-pixbuf,
  gtk4,
  gtk4-layer-shell,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "nwg-drawer";
  version = "0.5.1";

  src = fetchCrate {
    inherit (finalAttrs) pname version;
    hash = "sha256-2p2m5EVYn6TbJYanKH64dN3jKxCxQpBrDd60cv8cjok=";
  };

  nativeBuildInputs = [
    pkg-config
  ];
  buildInputs = [
    pango
    glib
    gdk-pixbuf
    gtk4
    gtk4-layer-shell
  ];

  cargoHash = "sha256-p9aMTFZJ35Fm2Td6bxbtSe9gBZfacZ1GrGXPLzFWTV0=";
  cargoDepsName = finalAttrs.pname;
})
