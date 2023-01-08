{ lib, stdenv, callPackage, writeText, fetchHex, erlang, rebar3 }:

let
  inherit (builtins) head elem elemAt listToAttrs getAttr hasAttr concatStringsSep;
  inherit (callPackage ./lib.nix {}) readErl;

  supportedConfigVsns = [ "1.2.0" ];
in {
  buildRebar3 = {
    root,
      pname,
      version,
      releaseType ? "app",
      profile ? "default",
      checkouts ? {},
      singleStep ? false,
      ...
  }@attrs: let
    deps = let
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
    in lib.trivial.warnIfNot (elem vsn supportedConfigVsns)
      "Unsupported lock file. Proceeding anyway..."
      (listToAttrs (map (x: let
        name = head x;
        src = elemAt x 1;
        tbl = {
          pkg = fetchHex {
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
        locks) // checkouts);

    depsDrv = stdenv.mkDerivation {
      pname = "${pname}-deps";
      inherit version;

      src = builtins.path {
        path = root;
        name = "source";
        filter = path: type: let
          base = baseNameOf path;
        in if type == "directory" then base == "_checkouts"
           else base == "rebar.config" || base == "rebar.config.script" || base == "rebar.lock";
      };

      # OTP 25.1/26.0 will make this obsolete with erlang/otp#5965
      # being merged, which makes Parsetools respect +deterministic.
      postUnpack = ''
        # Canonicalize path since e.g. Parsetools will output absolute paths
        mv --no-clobber --no-target-directory "$sourceRoot" source
        sourceRoot=source
      '';

      configurePhase = ''
        mkdir -p _checkouts
        ${concatStringsSep "\n" (lib.mapAttrsToList
          (name: value: ''cp --no-preserve=mode -r "${value}" _checkouts/${name}'')
          deps)}
      '';

      buildPhase = ''
        export ERL_COMPILER_OPTIONS=[deterministic]
        REBAR_CACHE_DIR=.rebar-cache REBAR_OFFLINE=1 DEBUG=1 ${rebar3}/bin/rebar3 as ${profile} compile --deps_only
      '';
      installPhase = ''mv _build $out'';
    };

    specialParams = [ "releaseType" "profile" "checkouts" "singleStep" ];
  in stdenv.mkDerivation (removeAttrs attrs specialParams // {
    src = root;

    buildInputs = [ erlang rebar3 ] ++ attrs.buildInputs or [];

    setupHook = attrs.setupHook or
      (if releaseType == "app"
       then writeText "setupHook.sh" ''addToSearchPath ERL_LIBS $1/lib/erlang/lib''
       else null);

    postUnpack = attrs.postUnpack or ''
      mv --no-clobber --no-target-directory "$sourceRoot" source
      sourceRoot=source
    '';

    configurePhase = attrs.configurePhase or ''
      runHook preConfigure
      mkdir -p _checkouts
      ${concatStringsSep "\n" (lib.mapAttrsToList
        (name: value: ''cp --no-preserve=mode -r "${value}" _checkouts/${name}'')
        deps)}
      ${lib.optionalString (!singleStep)
        ''cp --no-preserve=mode -r --no-target-directory ${depsDrv} _build''}
      runHook postConfigure
    '';

    buildPhase = attrs.buildPhase or ''
      runHook preBuild
      export ERL_COMPILER_OPTIONS=[deterministic]
      REBAR_CACHE_DIR=.rebar-cache REBAR_OFFLINE=1 DEBUG=1 rebar3 as ${profile} ${if releaseType == "app" then "compile" else releaseType}
      runHook postBuild
    '';

    installPhase = attrs.installPhase or ''
      runHook preInstall
      path="$(TERM=dumb rebar3 as ${profile} path --separator=: \
        --${if releaseType == "app" then "ebin"
            else if releaseType == "release" then "rel"
            else if releaseType == "escriptize" then "bin"
            else throw "The argument 'releaseType' has to be one of 'app', 'release' or 'escriptize'"})"
      path="''${path##===> *
      }"
      ${if releaseType == "app"
        then ''
          mkdir -p $out/lib/erlang/lib
          IFS=: read -ra ebins <<<"$path"
          for ebin in "''${ebins[@]}"; do
            appdir="$(dirname "$ebin")"
            find "$appdir" -xtype l -delete # Remove broken symlinks
            cp --dereference -r "$appdir" $out/lib/erlang/lib
          done
        '' else ''
          mkdir -p $out/bin
          cp -r $path $out
          ${lib.optionalString (releaseType == "release")
            ''
              find $out/rel/*/bin -type f -executable -exec ln -st $out/bin {} +
              # Remove references to erlang to reduce closure size
              for f in $out/rel/*/erts-*/bin/${if
                # Newer versions of relx use dyn_erl instead of the erl shell script
                (lib.versionAtLeast rebar3.version "3.19.0") then "start" else "{erl,start}"}; do
                 substituteInPlace "$f" --replace ${erlang}/lib/erlang "''${f%/erts-*/bin/*}"
              done
            ''}
        ''}
      runHook postInstall
    '';

    meta = {
      inherit (erlang.meta) platforms;
    } // attrs.meta or {};
  });
}
