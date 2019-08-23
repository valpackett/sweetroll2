# Used by "mix format"
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  import_deps: [:plug, :ex_early_ret],
  locals_without_parens: [
    deftpl: 2,
    ret_if: :*
  ]
]
