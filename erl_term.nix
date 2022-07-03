# Parser for literal Erlang terms
{ pkgs ? import <nixpkgs> {}
  # Whether to use the Erlang term parser implemented in Nix or shell
  # out to an Erlang interpreter.
, usePureFromErl ? true
}:

let
  inherit (builtins) substring fromJSON readFile;
  inherit (pkgs) lib runCommand;

  skipWs = s: builtins.elemAt (builtins.match "([[:space:]]|%[^\n]*\n?)*(.*)" s) 1;
  sepBy = { beg ? "", sep, end ? null }: c: s: let
    c' = x: s: c x (if end == null then "" else substring (builtins.stringLength end) (-1) s);
    isEnd = if end == null then s: s == "" else lib.hasPrefix end;
    f = acc: term (x: s:
      let s' = skipWs s;
          acc' = acc ++ [x];
      in if lib.hasPrefix sep s'
         then let s'' = skipWs (substring (builtins.stringLength sep) (-1) s');
              in (if s'' == "" then c' else f) acc' s''
         else c' acc' s');
    s' = skipWs (substring (builtins.stringLength beg) (-1) s);
  in if isEnd s' then c' [] s' else f [] s';

  list = sepBy { beg = "["; sep = ","; end = "]"; };
  tuple = sepBy { beg = "{"; sep = ","; end = "}"; };

  parseString = isBin: c: s: let
    x = builtins.head (builtins.match ''${if isBin then "<<" else ""}("(\\"|[^"])*").*'' s);
  in c (builtins.fromJSON x)
    (substring (builtins.stringLength x + (if isBin then 4 else 0)) (-1) s);

  number = c: s: let
    x = builtins.head (builtins.match ''([0-9]+).*'' s);
  in c (builtins.fromJSON x) (substring (builtins.stringLength x) (-1) s);
  atom = c: s: let
    x = builtins.head (builtins.match ''([a-z][A-Za-z0-9@]*).*'' s);
  in c x (substring (builtins.stringLength x) (-1) s);

  term = let
    tbl = {
      "[" = list; "{" = tuple; "\"" = parseString false; "<" = parseString true;
      "'" = throw "TODO: quoted atoms";
      "0" = number; "1" = number; "2" = number; "3" = number; "4" = number;
      "5" = number; "6" = number; "7" = number; "8" = number; "9" = number;
    };
  in c: s: let
    ch = substring 0 1 s;
  in (if builtins.hasAttr ch tbl then builtins.getAttr ch tbl else atom) c s;

  consult = sepBy { sep = "."; };
  fromErl = s: consult (x: _s: x) (skipWs s);

  jsone = pkgs.beamPackages.buildRebar3 rec {
    name = "jsone";
    version = "1.7.0";
    src = pkgs.fetchFromGitHub {
      owner = "sile";
      repo = name;
      rev = version;
      sha256 = "gdke3pFslgg+PmDUQCUWYBszml6EAYcfewBvLWhD398=";
    };
  };
in {
  readErl =
    # if usePureFromErl && false then f: fromErl (readFile f)
    # else
      f: fromJSON (readFile (runCommand "read-erl"
      {
        buildInputs = [ jsone ];
        allowSubstitutes = false;
        preferLocalBuild = true;
      }
      ''
      >$out ${pkgs.erlang}/bin/erl -noinput \
        -eval '{ok, Terms} = file:consult("${f}"),
io:put_chars(jsone:encode(Terms)).' \
        -s init stop
    ''));
  
  x = fromErl ''[ "hej" , <<"gey">>, 42, {3, "he", 5}, 4, atom ]. 3. 4 . '';
}
