{ pkgs ? import <nixpkgs> {} }:

let
  inherit (builtins) head elemAt listToAttrs getAttr hasAttr groupBy toString zipAttrsWith concatStringsSep;
  inherit (pkgs) lib stdenv beamPackages;
  inherit (lib) mapAttrsToList;
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
    deps = listToAttrs (map (x: let
      name = head x;
      src = elemAt x 1;
      _lvl = elemAt x 2;
      tbl = {
        pkg = beamPackages.fetchHex {
          pkg = elemAt src 1;
          version = elemAt src 2;
          sha256 = getAttr name hashes;
        };
        git = fetchGit {
          url = elemAt src 1;
          rev = elemAt (elemAt src 2) 1;
        };
        path = throw "TODO: path dependency";
      };
      type = head src;
    in if builtins.hasAttr type tbl
       then { inherit name; value = builtins.getAttr type tbl; }
       else throw "Unsupported dependency type ${type} for ${name}")
      locks);

    depsDrv = stdenv.mkDerivation {
      pname = "${pname}-deps";
      inherit version;
      src = builtins.filterSource
        (path: type: let
          base = baseNameOf path;
        in if type == "directory" then base == "_checkouts" else base == "rebar.config" || base == "rebar.lock" || base == "rebar.config.script")
        path;
      REBAR_OFFLINE = true;

      buildPhase = ''
        mkdir -p _checkouts
        ${concatStringsSep "\n" (mapAttrsToList
          (name: value: ''[[ -d _checkouts/${name} ]] || cp --no-preserve=mode -r "${value}" _checkouts/${name}'')
          deps)}
        ${beamPackages.rebar3}/bin/rebar3 compile --deps_only
        ls
      '';

      installPhase = ''
        mv _build $out
      '';
    };

    rel = lib.trivial.warnIfNot
      (builtins.elem vsn supportedConfigVsns)
      "Unsupported lock file. Proceeding anyway..."
      (beamPackages.rebar3Relx {
        inherit pname version;
        src = path;

        # REBAR_IGNORE_DEPS = true;
        REBAR_OFFLINE = true;

        # TODO Lockfiles
        # profile = "prod";

        preBuild = ''
          mkdir -p _checkouts
          ${concatStringsSep "\n" (mapAttrsToList
            (name: value: ''[[ -d _checkouts/${name} ]] || cp --no-preserve=mode -r "${value}" _checkouts/${name}'')
            deps)}
          cp --no-preserve=mode -r ${depsDrv} _build
        '';

        releaseType = "escript";
      });
  in rel;
}
