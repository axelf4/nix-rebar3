{
  description = "hejj";

  outputs = { self, nixpkgs }: let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    nix-rebar3 = import ./. {
      inherit pkgs;
    };
    # x = nix-rebar3.readErl ./term.erl;
  in {
    packages.x86_64-linux.hello = nix-rebar3.buildRebar3 {
      path = ./myapp;
      name = "myapp";
      version = "0.1.0";
    };
  };
}
