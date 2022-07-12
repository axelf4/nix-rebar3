{
  description = "Build rebar3 projects in Nix";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }: flake-utils.lib.eachDefaultSystem (system: let
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    lib = pkgs.callPackage ./. {};

    packages = {
      rebar3_path_deps = pkgs.beamPackages.callPackage ./rebar3_path_deps.nix {};
    };
  }) // {
    overlay = final: prev: final.callPackage ./. {};
  };
}
