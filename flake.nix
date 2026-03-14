{
  inputs = {
    systems.url = "github:nix-systems/default";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
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
          default = pkgs.rustPlatform.buildRustPackage {
            pname = "zellij-switch";
            version = "0.2.1";
            src = ./.;
            cargoLock.lockFile = ./Cargo.lock;
            
            nativeBuildInputs = [ rustToolchain ];

            buildPhase = ''
              cargo build --target wasm32-wasip1 --release
            '';

            installPhase = ''
              mkdir -p $out/bin
              cp target/wasm32-wasip1/release/*.wasm $out/bin/
            '';

            doCheck = false;
          };
        });

      defaultPackage = eachSystem (system:
        self.packages.${system}.default);

      overlays.default = final: prev: {
        zellij-switch = self.packages.${prev.stdenv.hostPlatform.system}.default;
      };

      devShells = eachSystem (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ rust-overlay.overlays.default ];
          };
          rustToolchain = pkgs.rust-bin.stable.latest.default.override {
            extensions = [ "rust-src" "rust-analyzer" ];
            targets = [ "wasm32-wasip1" ];
          };
        in
        {
          default = pkgs.mkShell {
            nativeBuildInputs = [
              rustToolchain
            ];
          };
        });
    };
}
