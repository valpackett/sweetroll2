defmodule Mix.Tasks.Sweetroll2.Import do
  use Mix.Task

  @shortdoc "Import JSON Lines files into the Mnesia DB"

  @impl Mix.Task
  @doc false
  def run(raw_args) do
    {switches, argv, _} = OptionParser.parse(raw_args, strict: [domain: [:string, :keep]])

    domains =
      Enum.reduce(switches, [], fn
        {:domain, d}, acc -> [d | acc]
        _, acc -> acc
      end)

    Mix.shell().info("Ignoring domains #{inspect(domains)}")
    Memento.start()

    for path <- argv do
      Mix.shell().info("Importing #{path}")
      Sweetroll2.Doc.import_json_lines(File.read!(path), domains)
      Mix.shell().info("Finished importing #{path}")
    end
  end
end
