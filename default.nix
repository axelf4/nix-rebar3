{ pkgs ? import <nixpkgs> {} }:

let
  inherit (builtins) head elemAt listToAttrs getAttr hasAttr;
  inherit (pkgs) lib;
  inherit (import ./lib.nix { inherit pkgs; }) readErl;

  supportedConfigVsns = [ "1.2.0" ];
in {
  buildRebar3 = {
    path, pname, version
  }: let
    terms = readErl (path + "/rebar.lock");
    vsn = head (head terms);
    locks = elemAt (head terms) 1;
    attrs = elemAt terms 1;
    hashes = listToAttrs (map
      (x: { name = head x; value = elemAt x 1; })
      (elemAt (lib.findFirst
        (x: head x == "pkg_hash_ext")
        (throw "pkg_hash_ext not found")
        attrs) 1));
    deps = map
      (x: let
        name = head x;
        src = elemAt x 1;
        tbl = {
          pkg = pkgs.beamPackages.fetchHex {
            pkg = elemAt src 1;
            version = elemAt src 2;
            sha256 = getAttr name hashes;
          };
        };
        type = head src;
      in if builtins.hasAttr type tbl
         then builtins.getAttr type tbl
         else throw "Unsupported dependency type ${type} for ${name}")
      locks;
  in lib.trivial.warnIfNot
    (builtins.elem vsn supportedConfigVsns)
    "Unsupported lock file. Proceeding anyway..."
    (pkgs.beamPackages.buildRebar3 {
      name = pname;
      inherit version;
      src = path;

      # REBAR_IGNORE_DEPS = true;

      beamDeps = deps;

      # releaseType = "escript";
    });
}
