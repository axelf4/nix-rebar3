# Parser for literal Erlang terms
{ lib, fetchFromGitHub, runCommand, buildHex, erlang }:

{
  # Whether to use the Erlang term parser implemented in Nix or shell
  # out to an Erlang interpreter.
  usePureFromErl ? true
}:

let
  inherit (builtins) head match stringLength substring fromJSON readFile;

  skipWs = s: builtins.elemAt (match "([[:space:]]|%[^\n]*\n?)*(.*)" s) 1;
  sepBy = { beg ? "", sep, end ? "" }: s: c: let
    c' = s: c (substring (stringLength end) (-1) s);
    f = s: acc: term s (s: x:
      let s' = skipWs s;
          acc' = acc ++ [x];
      in if lib.hasPrefix sep s'
         then let s'' = skipWs (substring (stringLength sep) (-1) s');
              in (if s'' == "" then c' else f) s'' acc'
         else c' s' acc');
    s' = skipWs (substring (stringLength beg) (-1) s);
  in (if end != "" -> !lib.hasPrefix end s' then f else c') s' [];

  list = sepBy { beg = "["; sep = ","; end = "]"; };
  tuple = sepBy { beg = "{"; sep = ","; end = "}"; };

  parseString = isBin: s: c: let
    x = head (match ''${if isBin then "<<" else ""}("(\\"|[^"])*").*'' s);
  in c (substring (stringLength x + (if isBin then 4 else 0)) (-1) s)
    (fromJSON x);

  number = s: c: let
    x = head (match ''([0-9]+).*'' s);
  in c (substring (stringLength x) (-1) s) (fromJSON x);
  atom = s: c: let
    x = head (match ''([a-z][A-Za-z0-9_@]*).*'' s);
  in c (substring (stringLength x) (-1) s) x;

  term = let
    tbl = {
      "[" = list; "{" = tuple; "\"" = parseString false; "<" = parseString true;
      "'" = throw "TODO: quoted atoms";
      "0" = number; "1" = number; "2" = number; "3" = number; "4" = number;
      "5" = number; "6" = number; "7" = number; "8" = number; "9" = number;
    };
  in s: let
    ch = substring 0 1 s;
  in (if builtins.hasAttr ch tbl then builtins.getAttr ch tbl else atom) s;

  consult = sepBy { sep = "."; };
  fromErl = s: consult (skipWs s) (_s: x: x);

  jsone = buildHex {
    name = "jsone";
    version = "1.7.0";
    sha256 = "o6M3Eu5ryL4Qz6IcfEJaKZ3kxahTP5+THld6bQ6PXb0=";
  };
in {
  readErl =
    if usePureFromErl then f: fromErl (readFile f)
    else f: fromJSON (readFile (runCommand "read-erl"
      {
        buildInputs = [ jsone ];
        allowSubstitutes = false;
        preferLocalBuild = true;
      }
      # TODO Escape filename and encode tuples as lists not objects
      ''
      >$out ${erlang}/bin/erl -noinput \
        -eval '{ok, Terms} = file:consult("${f}"),
io:put_chars(jsone:encode(Terms)).' \
        -s init stop
    ''));
}
