
def to-c []: [
  string -> string
  binary -> string
] {
  into binary | chunks 1 | each {into int} | append 0 | str join "," | $"{($in)}"
}

const self = path self

export def main [...paths: path, --force, --tree-sitter: path, --output: path = target] {
  let paths = $paths | each {path expand}
  let tree_sitter = $tree_sitter | path expand
  let output = $output | path expand
  cd ($self | path dirname)
  
  mkdir tmp
  mkdir ($output | path join "langs")

  mkdir include
  ln -s (echo ($tree_sitter)/lib/src | path expand) include/tree_sitter

  let grammars = $paths
  | each {|path|
    open ($path | path join tree-sitter.json) | get grammars
    | upsert path {|r| $path | path join ($r | get -o path | default "")}
    | upsert highlights {$in | default []}
    | where highlights != []
    | update highlights {
      $in
      | append []
      | each {|rel| $path | path join $rel}
      | where ($it | path exists)
      | each {open $in}
      | str join "\n"
    }
  }
  | flatten
  | update name {str replace -ar '\W' '_'}
  | upsert file-types {default []}
  | where name != flow
  | select -o name path file-types highlights

  $grammars | par-each {|grammar| 
    let name = $grammar.name
    let path = $grammar.path

    let path_wasm = $output | path join $"langs/($name).wasm"
    let path_c = $"tmp/($name).c"

    if not $force and ($path_wasm | path exists) {
      print $"(ansi grey)stale(ansi reset) ($name)"
      return
    }

$"
#include <tree_sitter/api.h>

__attribute__\(\(import_module\(\"typst_env\")))
void wasm_minimal_protocol_write_args_to_buffer\(void *buf);

int typsitter\(const TSLanguage *language, char *highlights, size_t source_len);

const char _typsitter_highlights[] = ($grammar.highlights | to-c);
const char *typsitter_highlights\() {
  return _typsitter_highlights;
}

const TSLanguage *tree_sitter_($name)\(void);
const TSLanguage *typsitter_lang\() {
  return tree_sitter_($name)\();
}
" | save -f $path_c

    let c_files = [src/parser.c src/scanner.c] | each {|rel| $path | path join $rel} | where {path exists}

    print $"(ansi blue)build(ansi reset) ($name)"
    let start = date now

    (emcc
      -I include
      -I ($tree_sitter)/lib/include
      -I ($tree_sitter)/lib/src
      typsitter.c $path_c
      ($tree_sitter)/lib/src/lib.c
      ...$c_files
      -s ERROR_ON_UNDEFINED_SYMBOLS=0
      --no-entry -O3
      -o $path_wasm
    )

    wasi-stub $path_wasm -o $path_wasm | ignore

    let time = (date now) - $start
    print $"(ansi green)built(ansi reset) ($name) (ansi grey)($time)(ansi reset)"
  }

  $grammars | each {|grammar|
    let name = $grammar.name
$"
  ($name): \(
    fn: \() => plugin.transition\(plugin\(\"./langs/($name).wasm\").typsitter_init).typsitter_highlight,
    file_types: \(($grammar.file-types | each {to json | $"($in),"} | str join)),
  ),
"
  } | str join |
$"
#state\(\"typsitter:langs\", \(:)).update\(langs => \(
  ..langs,
  ($in)
))
"
   | save -f ($output | path join langs.typ)

}

