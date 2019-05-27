# Used by "mix format"
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  import_deps: [:plug],
  locals_without_parens: [
    deftpl: 2
  ]
]
