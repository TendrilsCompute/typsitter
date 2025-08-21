{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    let
      typsitterMkDerivation = import ./typsitter.nix;
      typsitterDefaultGrammars = import ./grammars.nix;
    in
    {
      lib = {
        inherit typsitterMkDerivation typsitterDefaultGrammars;
        src = ./typsitter.typ;
      };
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      {
        formatter = pkgs.nixfmt-tree;

        packages = {
          default = pkgs.callPackage typsitterMkDerivation {
            typsitterGrammars = typsitterDefaultGrammars pkgs;
          };
          minimal = pkgs.callPackage typsitterMkDerivation {
            typsitterGrammars = { inherit (typsitterDefaultGrammars pkgs) rust; };
          };
        };

        devShells.default = pkgs.mkShell {
          name = "typsitter-dev";
          nativeBuildInputs = with pkgs; [
            nushell
            emscripten
          ];
        };
      }
    );
}
