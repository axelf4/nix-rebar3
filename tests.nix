{ pkgs, check-utils }:

let
  inherit (check-utils pkgs) isEqual;
  inherit (pkgs.callPackage ./lib.nix {}) fromErl;
in {
  ignoresIntermixedWs = isEqual (fromErl " \t\n4 \t\n. \t\n") [ 4 ];

  canParseAtom = isEqual (fromErl "foo.") [ "foo" ];

  parsesSeparatedItems = isEqual
    (fromErl ''[1, 2]. {"a", <<"b">>}.'')
    [ [ 1 2 ] [ "a" "b" ] ];
}
