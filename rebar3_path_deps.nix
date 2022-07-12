{ lib, buildHex }:

buildHex {
  name = "rebar3_path_deps";
  version = "0.4.0";
  sha256 = "Qz3b6hZKziY8mEj/9nOEP4KbwvEPsLiTSF8f414f5jo=";

  meta = {
    description = "A rebar plugin to specify path dependencies";
    license = lib.licenses.asl20;
    homepage = "https://github.com/benoitc/rebar3_path_deps";
  };
}
