{
  description = "hejj";

  outputs = { self, nixpkgs }: let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    nix-rebar3 = import ./erl_term.nix {
      inherit pkgs;
      usePureFromErl = false;
    };
    x = nix-rebar3.readErl ./term.erl;
  in {
    packages.x86_64-linux.hello = x;
  };
}
