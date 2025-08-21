
#let langs = state("typsitter:langs", (:))

#let read-u32(bytes, index) = {
  bytes.at(index) + bytes.at(index + 1) * 256 + bytes.at(index + 2) * 65536 + bytes.at(index + 3) * 16777216
}

#let get-segments(lang, source, prefix: "", suffix: "") = {
  if lang == none {
    return ((scope: "", text: source),)
  }
  let source = bytes(source)
  let prefix = bytes(prefix)
  let suffix = bytes(suffix)
  let bytes = (langs.get().at(lang).fn)()(prefix + source + suffix)

  let index = 0
  let last_end = 0
  let segments = ()
  while index < bytes.len() {
    let start = read-u32(bytes, index) - prefix.len();
    let end = read-u32(bytes, index + 4) - prefix.len();
    let len = read-u32(bytes, index + 8);
    index += 12;
    let scope = str(bytes.slice(index, count: len))
    index += len;  
    start = calc.min(calc.max(start, last_end), source.len())
    end = calc.min(calc.max(end, last_end), source.len())
    if start > last_end {
      segments.push((scope: "", text: str(source.slice(last_end, start))))
    }
    if end > start {
      segments.push((scope: scope, text: str(source.slice(start, end))))
    }
    last_end = end;
  }
  if last_end < source.len() {
    segments.push((scope: "", text: str(source.slice(last_end))))
  }

  segments
}

#let detect-lang(lang) = {
  let langs = langs.get()
  if lang == none {
    none
  } else if lang in langs {
    lang
  } else {
    for (id, info) in langs {
      if lang in info.file_types {
        return id
      }
    }
  }
}

#let theme-lookup(theme, scope) = {
  while scope != "" and not scope in theme {
    scope = scope.replace(regex("\.?[^.]+$"), "")
  }
  theme.at(scope, default: theme.fg)
}

#let scope-classes(scope) = {
  if scope != "" {
    scope.split(".").enumerate().map(((i, name)) => "ts" + "-" * (i+1) + name)
  } else {
    ()
  }
}

#let theme-css(theme) = {
  for (scope, color) in theme {
    let color = color.to-hex();
    if scope == "fg" {
      ".ts {color:"+color+"}\n"
    } else if scope == "bg" {
      ".ts {background-color:"+color+"}\n"
    } else {
      scope-classes(scope).map(x => "." + x).join(" ") + " {color:"+color+"}\n"
    }
  }
}

#let block_ = block

#let render(theme, lang: none, html_support: false, prefix: "", suffix: "", block: true, code) = context {
  if html_support and target() == "html" {
    html.elem(if block { "pre" } else { "code" }, attrs: (class: "ts"), [
      #for segment in get-segments(lang, code, prefix: prefix, suffix: suffix) {
        if segment.scope == "" {
          segment.text
        } else {
          html.elem("span", attrs: (class: scope-classes(segment.scope).join(" ")), segment.text)
        }
      }
    ])
  } else {
    (if block { block_ } else { box })(fill: theme.bg, {
      for segment in get-segments(lang, code) {
        text(fill: theme-lookup(theme, segment.scope), segment.text)
      }
    })
  }
}

#let register(theme, html_support: false) = content => {
  show raw.where(block: true): it => context render(
    theme,
    lang: detect-lang(it.lang),
    html_support: html_support,
    it.text,
  )
  content
}

