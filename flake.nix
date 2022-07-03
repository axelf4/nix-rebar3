{
  description = "Build rebar3 projects in Nix";

  outputs = { self, nixpkgs }: {
    lib = nixpkgs.lib.genAttrs [ "x86_64-linux" ]
      (system: nixpkgs.legacyPackages.${system}.callPackage ./. {});
  };
}
