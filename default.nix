{ pkgs ? import <nixpkgs> {} }:

let
  inherit (builtins) head elemAt listToAttrs getAttr hasAttr groupBy toString zipAttrsWith;
  inherit (pkgs) lib beamPackages;
  inherit (beamPackages.callPackage ./lib.nix {} {}) readErl;

  buildRebar3' = beamPackages.callPackage ./build-rebar3.nix {};

  supportedConfigVsns = [ "1.2.0" ];
in rec {
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
    deps = { "0" = []; } // zipAttrsWith (_lvl: deps: deps) (map
      (x: let
        name = head x;
        src = elemAt x 1;
        lvl = elemAt x 2;
        tbl = {
          pkg = let
            pkg = elemAt src 1;
            version = elemAt src 2;
          in buildRebar3 {
            pname = pkg;
            inherit version;
            path = beamPackages.fetchHex {
              inherit pkg version;
              sha256 = getAttr name hashes;
            };
            # beamDeps = if hasAttr (toString (lvl + 1)) deps
            #            then getAttr (toString (lvl + 1)) deps
            #            else [];
          };
          git = buildRebar3' {
            inherit name;
            version = "git";
            src = fetchGit {
              url = elemAt src 1;
              rev = elemAt (elemAt src 2) 1;
            };
          };
        };
        type = head src;
      in if builtins.hasAttr type tbl
         then { "${toString lvl}" = builtins.getAttr type tbl; }
         else throw "Unsupported dependency type ${type} for ${name}")
      locks);

    rel = lib.trivial.warnIfNot
      (builtins.elem vsn supportedConfigVsns)
      "Unsupported lock file. Proceeding anyway..."
      (beamPackages.rebar3Relx {
        # name = pname;
        inherit pname version;
        src = path;

        # REBAR_IGNORE_DEPS = true;

        beamDeps = deps."0";

        releaseType = "escript";
      });
  in rel;
}
