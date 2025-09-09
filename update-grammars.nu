open grammars.json
  | transpose name grammar
  | par-each -k {|i|
    let rev = git ls-remote $i.grammar.git HEAD | parse "{rev}\t{_}" | get 0.rev
    let tmp = mktemp -d
    let hash = do {
      cd $tmp
      http get $"($i.grammar.git)/archive/($rev).tar.gz" | tar -x
      nix hash path (ls | get name | first)
    }
    rm -rf $tmp
    $i | upsert grammar.rev $rev | upsert grammar.hash $hash
  }
  | transpose -rd
  | save -f grammars.json
