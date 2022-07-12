{
  description = "hejj";

  inputs = {
    nix-rebar3 = {
      url = "..";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-rebar3 }: let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    # x = nix-rebar3.readErl ./term.erl;
  in {
    packages.x86_64-linux = rec {
      hello = nix-rebar3.lib.x86_64-linux.buildRebar3 {
        root = ./.;
        pname = "myapp";
        version = "0.1.0";
        releaseType = "escript";
      };

      default = hello;
    };
  };
}
