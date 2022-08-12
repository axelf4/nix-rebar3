# Parser for literal Erlang terms
{ lib }:

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
  in (if end != "" && lib.hasPrefix end s' then c' else f) s' [];

  list = sepBy { beg = "["; sep = ","; end = "]"; };
  tuple = sepBy { beg = "{"; sep = ","; end = "}"; };

  string = isBin: s: c: let
    x = head (match ''${if isBin then "<<" else ""}("(\\"|[^"])*").*'' s);
  in c (substring (stringLength x + (if isBin then 4 else 0)) (-1) s) (fromJSON x);

  number = s: c: let
    x = head (match ''([0-9]+).*'' s);
  in c (substring (stringLength x) (-1) s) (fromJSON x);
  atom = s: c: let
    x = head (match ''([a-z][A-Za-z0-9_@]*).*'' s);
  in c (substring (stringLength x) (-1) s) x;
  qatom = s: c: let
    x = head (match "'([^']*)'.*" s);
  in c (substring (stringLength x + 2) (-1) s) x;

  term = let
    tbl = {
      "[" = list; "{" = tuple; "\"" = string false; "<" = string true;
      "'" = qatom;
      "0" = number; "1" = number; "2" = number; "3" = number; "4" = number;
      "5" = number; "6" = number; "7" = number; "8" = number; "9" = number;
    };
  in s: let
    ch = substring 0 1 s;
  in (if builtins.hasAttr ch tbl then builtins.getAttr ch tbl else atom) s;

  fromErl = s: sepBy { sep = "."; } (skipWs s) (_s: x: x);
in {
  readErl = f: fromErl (readFile f);
}
