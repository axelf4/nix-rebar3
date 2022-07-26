# nix-rebar3

This is a Nix library aiming to be an alternative to [rebar3_nix] that
does not require code generation, similar to [mix-to-nix] but for
rebar3 instead of Mix.

## Usage

```nix
nix-rebar3.lib.${system}.buildRebar3 {
  root = ./.;
  pname = "myapp";
  version = "1.0.0";
  releaseType = "release"; # or "escriptize"
  profile = "prod";
}
```

Note that for running a built release you either need to first copy
the files out of the read-only Nix store, or set the
`RELX_OUT_FILE_PATH` environment variable to a suitable location,
since the extended start script generated by [relx] by default will
write files under the release root directory.

## Background

This section summarizes the existing support for packaging rebar3
projects in Nixpkgs. Apart from the regular `nixpkgs.rebar3`
attribute, which is adequate for interactive usage, there is also a
patched version that makes it possible to provide paths to pre-built
rebar3 plugins to include with

    nixpkgs.rebar3WithPlugins { plugins = [ ... ] }
	
(which passes them through an internal `REBAR_GLOBAL_PLUGINS`
environment variable) to avoid rebar3 choking on trying to download
missing plugins during sandboxed builds. When using
`rebar3WithPlugins`, in addition to manually specified plugins, a
custom [`rebar_ignore_deps`][rebar_ignore_deps.erl] is always
included, that, when the environment variable `REBAR_IGNORE_DEPS` is
non-empty, override the `install_deps` rebar3 provider to instead
proceed with the build as if there were no declared dependencies.

There are choices that can be made when packaging rebar3 projects with
Nix in general regarding library Erlang application dependencies. They
may be built en masse in a separate derivation, or individually with
one derivation each. To prevent Rebar3 from managing and downloading
the dependencies, one can either: Copy them into the
[`_checkouts`][Checkout Dependencies] top-level directory; or
reference built library dependencies in the [`ERL_LIBS`][Code Path]
environment variable, and using the [`bare
compile`][rebar_prv_bare_compile.erl] rebar3 provider instead of
`compile` (which skips trying to build dependencies,) or setting
`REBAR_IGNORE_DEPS` to true (see above.) Note that it is not possible
to include multiple versions of the same application in Erlang/rebar3;
the lock file in the top level project is authoritative, with an
algorithm for determining the versions to fetch, see [Source
Dependencies]; and rebar3 plugins may technically interfere when
building other dependencies; and therefore building libraries
individually can produce unexpected results.

With that said, the available rebar3 builders in Nixpkgs are:

* [`buildRebar3`][build-rebar3.nix]: Builds Erlang applications using
  `rebar3 bare compile`.

  The built package will export a [setup hook][Package setup hooks]
  that adds the built applications to `ERL_LIBS`. All dependencies
  have to be built similarly and passed in the `beamDeps` argument,
  which due to the setup hooks is here just an alias for
  `propagatedBuildInputs`.
* [`rebar3Relx`][rebar3-release.nix]: Builds relx releases or escript
  executables.

  Dependencies should be provided with `beamDeps` like above, at which
  point `REBAR_IGNORE_DEPS` is set.
* [`fetchRebar3Deps`][fetch-rebar-deps.nix]: Produces a fixed-output
  derivation (FOD) running `rebar3 get-deps`.
  
  The result can be used as the `checkouts` argument to `rebar3Relx`.
  
rebar3_nix is a tool that generates a `deps.nix` file you are
intended to check in to source control, which evaluates to an
attribute set containing all dependencies for some rebar3 project.
Rebar3 lock files are limited to the `default` profile, and do not
include plugin dependencies nor the precise subdependencies of some
dependency, but, being a rebar3 plugin, rebar3_nix has access to that
information and for any combination of profiles.

This library instead reads the rebar3 lock file with a pure Nix
parser, with the big upside of not requiring any additional generated
files. The downsides are that compiled dependencies are not shared
between different projects built with Nix, and that plugins and
dependencies not listed in the `default` profile, such as `test`
dependencies, and their transitive dependencies, have to be specified
manually.

[rebar3_nix]: https://github.com/erlang-nix/rebar3_nix
[mix-to-nix]: https://github.com/transumption/mix-to-nix
[relx]: http://erlware.github.io/relx/
[Source Dependencies]: https://rebar3.readme.io/docs/dependencies#source-dependencies
[Checkout Dependencies]: https://rebar3.readme.io/docs/dependencies#checkout-dependencies
[Code Path]: https://www.erlang.org/doc/man/code.html#code-path
[rebar_ignore_deps.erl]: https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/tools/build-managers/rebar3/rebar_ignore_deps.erl
[rebar_prv_bare_compile.erl]: https://github.com/erlang/rebar3/blob/main/apps/rebar/src/rebar_prv_bare_compile.erl
[build-rebar3.nix]: https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/beam-modules/build-rebar3.nix
[rebar3-release.nix]: https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/beam-modules/rebar3-release.nix
[fetch-rebar-deps.nix]: https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/beam-modules/fetch-rebar-deps.nix
[Package setup hooks]: https://nixos.org/manual/nixpkgs/stable/#ssec-setup-hooks
