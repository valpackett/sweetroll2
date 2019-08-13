defmodule NiceLogFormatter do
  alias IO.ANSI

  def format(level, message, timestamp, metadata) do
    # IO.inspect(metadata)
    metamap = Enum.into(metadata, %{})

    [
      fmt_time(timestamp),
      fmt_level(level),
      fmt_ctx(metamap),
      Enum.map(metamap[:event] || [], &fmt_evt/1),
      fmt_msg(message),
      "\n"
    ]
  rescue
    e -> "could not format: #{inspect({level, message, metadata, e})}"
  end

  defp fmt_time({_, {hour, min, sec, ms}}),
    do: [
      ANSI.light_black(),
      _pad_hms(hour),
      ":",
      _pad_hms(min),
      ":",
      _pad_hms(sec),
      ".",
      _pad_milli(ms),
      ANSI.reset()
    ]

  defp _pad_hms(x), do: x |> Integer.to_string() |> String.pad_leading(2, "0")
  defp _pad_milli(x), do: x |> Integer.to_string() |> String.pad_leading(3, "0")

  defp fmt_level(:info), do: [ANSI.blue(), "  INFO", ANSI.reset()]
  defp fmt_level(:debug), do: [ANSI.light_black(), " DEBUG", ANSI.reset()]
  defp fmt_level(:warn), do: [ANSI.yellow(), "  WARN", ANSI.reset()]
  defp fmt_level(:error), do: [ANSI.red(), " ERROR", ANSI.reset()]
  defp fmt_level(_), do: [ANSI.magenta(), "   WTF", ANSI.reset()]

  defp fmt_ctx(%{request_id: rid}),
    do: [" ", ANSI.cyan_background(), ANSI.black(), "HTTP:", rid, ANSI.reset()]

  defp fmt_ctx(%{job_id: jid}),
    do: [" ", ANSI.green_background(), ANSI.black(), "JOB:", to_string(jid), ANSI.reset()]

  defp fmt_ctx(%{timber_context: %{http: %{request_id: rid}}}), do: fmt_ctx(%{request_id: rid})
  defp fmt_ctx(%{timber_context: %{que: %{job_id: rid}}}), do: fmt_ctx(%{job_id: rid})
  defp fmt_ctx(_), do: []

  defp fmt_evt({key, val}),
    do: [" ", ANSI.bright(), ANSI.light_white(), to_string(key), ANSI.reset(), fmt_val(val)]

  defp fmt_val(m) when is_map(m),
    do:
      m
      |> Map.delete(:__struct__)
      |> Enum.flat_map(fn {key, val} ->
        [" ", ANSI.yellow(), to_string(key), ANSI.light_black(), ":", ANSI.reset(), fmt_val(val)]
      end)

  defp fmt_val(l) when is_list(l),
    do: [
      ANSI.light_black(),
      "[ ",
      ANSI.reset(),
      Enum.intersperse(Enum.map(l, &fmt_val/1), [ANSI.light_black(), ", ", ANSI.reset()]),
      ANSI.light_black(),
      " ]",
      ANSI.reset()
    ]

  defp fmt_val(s) when is_binary(s), do: s
  defp fmt_val(x), do: inspect(x)

  defp fmt_msg(nil), do: []
  defp fmt_msg(""), do: []
  defp fmt_msg(s), do: [ANSI.light_black(), " // ", ANSI.reset(), s]
end
