{
  description = "Build rebar3 projects in Nix";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }: flake-utils.lib.eachDefaultSystem (system: let
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    lib = pkgs.callPackage ./. {};

    checks = import ./tests.nix {
      inherit pkgs;
      inherit (flake-utils.lib) check-utils;
    };
  }) // {
    overlays.default = final: prev: final.callPackage ./. {};
  };
}
