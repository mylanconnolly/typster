{
  description = "A development environment with Rust, Elixir 1.18, and OpenSSL";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          name = "rust-elixir-shell";

          buildInputs = [
            pkgs.rustc
            pkgs.cargo
            pkgs.elixir
            pkgs.openssl
            pkgs.pkg-config
          ];

          LD_LIBRARY_PATH = nixpkgs.lib.makeLibraryPath [ pkgs.openssl ];
        };
      });
}