{
  description = "Grafana Loki";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  # Nixpkgs / NixOS version to use.

  outputs = { self, nixpkgs, flake-utils }:
    { } // (flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = { allowUnfree = true; };
        };
      in
      {
        devShells = {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              kind
              tanka
            ];
          };
        };
      }));
}
