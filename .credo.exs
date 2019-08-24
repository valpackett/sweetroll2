%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "src/", "test/", "web/", "apps/"],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      checks: [
        # not available with elixir 1.9 (??)
        {Credo.Check.Refactor.MapInto, false},
        {Credo.Check.Warning.LazyLogging, false},

        # reconfigure
        {Credo.Check.Readability.MaxLineLength, [priority: :low, max_length: 128]},
        {Credo.Check.Refactor.CyclomaticComplexity, [max_complexity: 12]},

        # opt in
        {Credo.Check.Warning.UnsafeToAtom, []},
        {Credo.Check.Readability.UnnecessaryAliasExpansion, []},
        {Credo.Check.Consistency.MultiAliasImportRequireUse, []},
        {Credo.Check.Design.DuplicatedCode, []},
        {Credo.Check.Refactor.AppendSingleItem, []},
        {Credo.Check.Refactor.DoubleBooleanNegation, []},
        {Credo.Check.Refactor.VariableRebinding, []},
        {Credo.Check.Warning.MapGetUnsafePass, []},
      ]
    }
  ]
}
