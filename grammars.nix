{ fetchzip, ... }:
builtins.foldl' (x: f: f x) ./grammars.json [
  builtins.readFile
  builtins.fromJSON
  (builtins.mapAttrs (
    _:
    {
      git,
      rev,
      hash,
      archive ? "${git}/archive/${rev}.tar.gz",
      ...
    }:
    fetchzip {
      url = archive;
      inherit hash;
    }
  ))
]
