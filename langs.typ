
state("typsitter:langs", (:)).update(langs => (
  ..langs,
  
  ivy: (
    fn: () => plugin.transition(plugin("./langs/ivy.wasm").typsitter_init).typsitter_highlight,
    file_types: ("iv",),
  ),

))
