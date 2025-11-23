{
  inputs = {
    nixpkgs.url = "nixpkgs";
    systems.url = "github:nix-systems/default";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = inputs @ { self, nixpkgs, systems, rust-overlay, ... }:
    let
      eachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      packages = eachSystem (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ rust-overlay.overlays.default ];
          };

          rustToolchain = pkgs.rust-bin.stable.latest.default.override {
            targets = [ "wasm32-wasip1" ];
          };
        in
        {
          default = pkgs.rustPlatform.buildRustPackage rec {
            pname = "zellij-switch";
            version = "0.2.0";
            cargoLock = { lockFile = ./Cargo.lock; };
            src = ./.;

            nativeBuildInputs = [
              rustToolchain
              pkgs.pkg-config
              pkgs.perl
            ];

            buildInputs = [
              pkgs.zlib
            ];

            cargo = "${rustToolchain}/bin/cargo";
            rustc = "${rustToolchain}/bin/rustc";

            cargoBuildFlags = [
              "--target" "wasm32-wasip1"
              "--release"
            ];

            buildPhase = ''
              "${cargo}" build ${pkgs.lib.concatStringsSep " " cargoBuildFlags}
            '';

            installPhase = ''
              mkdir -p $out/bin
              cp target/wasm32-wasip1/release/*.wasm $out/bin/ || true
            '';

            doCheck = false;

            meta = with pkgs.lib; {
              description = "zellij-switch (wasm build only)";
              license = licenses.mit;
            };
          };
        });

      defaultPackage = eachSystem (system: self.packages.${system}.default);
      overlays.default = final: prev: {
        zellij-switch = self.packages.${prev.stdenv.hostPlatform.system}.default;
      };
    };
}
