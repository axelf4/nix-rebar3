{
  description = "hejj";

  outputs = { self, nixpkgs }: let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    nix-rebar3 = import ./erl_term.nix { inherit pkgs; };
  in {
    packages.x86_64-linux.hello = nix-rebar3;
  };
}
