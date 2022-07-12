{ lib, stdenv, beamPackages, erlang, rebar3 }:

let
  inherit (builtins) head elem elemAt listToAttrs getAttr hasAttr concatStringsSep;
  inherit (beamPackages.callPackage ./lib.nix {} {}) readErl;

  supportedConfigVsns = [ "1.2.0" ];
in {
  buildRebar3 = {
    root,
      pname,
      version,
      releaseType,
      profile ? "default"
  }@userAttrs: let
    terms = readErl (root + "/rebar.lock");
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
        path = root + "/${elemAt src 1}";
      };
      type = head src;
    in if hasAttr type tbl
       then { inherit name; value = getAttr type tbl; }
       else throw "Unsupported dependency type ${type} for ${name}")
      locks);

    depsDrv = stdenv.mkDerivation {
      pname = "${pname}-deps";
      inherit version;
      src = builtins.filterSource
        (path: type: let
          base = baseNameOf path;
        in if type == "directory" then base == "_checkouts"
           else base == "rebar.config" || base == "rebar.lock" || base == "rebar.config.script")
        root;

      REBAR_OFFLINE = true;

      configurePhase = ''
        mkdir -p _checkouts
        ${concatStringsSep "\n" (lib.mapAttrsToList
          (name: value: ''cp --no-preserve=mode -r "${value}" _checkouts/${name}'')
          deps)}
      '';

      buildPhase = ''HOME=. DEBUG=1 REBAR_BASE_DIR=$out ${rebar3}/bin/rebar3 as ${profile} compile --deps_only'';
      dontInstall = true;
    };

    rel = lib.trivial.warnIfNot (elem vsn supportedConfigVsns)
      "Unsupported lock file. Proceeding anyway..."
      (stdenv.mkDerivation (userAttrs // {
        inherit pname version;
        src = root;

        buildInputs = userAttrs.buildInputs or [] ++ [ erlang rebar3 ];

        REBAR_OFFLINE = true;

        configurePhase = ''
          runHook preConfigure
          mkdir -p _checkouts
          ${concatStringsSep "\n" (lib.mapAttrsToList
            (name: value: ''cp --no-preserve=mode -r "${value}" _checkouts/${name}'')
            deps)}
          cp --no-preserve=mode -r ${depsDrv} _build
          runHook postConfigure
        '';

        buildPhase = ''
          runHook preBuild
          HOME=1 DEBUG=1 rebar3 as ${profile} ${releaseType}
          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          dir=${if releaseType == "escriptize" then "bin" else "rel"}
          # mkdir -p $out
          cp --preserve=mode -r --no-target-directory _build/${profile}/$dir "$out"
          runHook postInstall
        '';

        meta = {
          inherit (erlang.meta) platforms;
        } // userAttrs.meta or {};
      }));
  in rel;
}
