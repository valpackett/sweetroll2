# Used by "mix format"
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  import_deps: [:ecto, :plug],
  locals_without_parens: [
    deftpl: 2
  ]
]
