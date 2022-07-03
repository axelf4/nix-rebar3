{ pkgs ? import <nixpkgs> {} }:

let
  inherit (import ./lib.nix { inherit pkgs; }) readErl;

  supportedConfigVsns = [ "1.2.0" ];
in {
  buildRebar3 = {
    path, name, version
  }: let
    terms = readErl (path + "/rebar.lock");
    vsn = builtins.head (builtins.head terms);
  in assert builtins.elem vsn supportedConfigVsns;
    {

    };
}
