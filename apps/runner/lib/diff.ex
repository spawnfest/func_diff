defmodule Runner.Diff do
  @moduledoc "Diff function bodies."

  @doc """
  Diff function bodies, `file_prefix` is provided to run `diff`
  in parallel without causing conflicts
  """
  def diff(text_a, text_b, file_prefix \\ "") do
    dir = System.tmp_dir!()

    file_a = Path.join(dir, file_prefix <> "_a")
    file_b = Path.join(dir, file_prefix <> "_b")

    File.write!(file_a, text_a <> "\n")
    File.write!(file_b, text_b <> "\n")

    result =
      Porcelain.exec(
        "diff",
        [file_a, file_b]
      )

    File.rm(file_a)
    File.rm(file_b)

    parse_result(result, text_a, text_b)
  end

  defp parse_result(%Porcelain.Result{status: 1, out: output}, text_a, text_b) do
    # drop trailing empty line
    lines_a = String.split(text_a, "\n") |> List.delete_at(-1)
    lines_b = String.split(text_b, "\n")

    diffs = String.split(output, "\n", trim: true)

    init_lines =
      Enum.map(lines_a, fn line ->
        {:common, line}
      end)

    parse_diff(init_lines, diffs, {0, 0, 0}, {lines_b, 0})
  end

  defp parse_result(_, _, _), do: []

  # defp parse_diff(lines, diffs, {pos_a, offset_a, offset_modifier}, {lines_b, pos_b})

  defp parse_diff(lines, [], _, _), do: lines

  defp parse_diff(lines, ["---" | rest_diff], a, b) do
    parse_diff(lines, rest_diff, a, b)
  end

  defp parse_diff(lines, ["<" <> _ | rest_diff], {pos_a, offset_a, _} = a, b) do
    parse_diff(
      List.update_at(lines, pos_a - 1 + offset_a, fn {:common, line} -> {:del, line} end),
      rest_diff,
      a,
      b
    )
  end

  defp parse_diff(lines, [">" <> _ | rest_diff], {pos_a, offset_a, offset_modifier}, {lines_b, pos_b}) do
    add_line = {:add, Enum.at(lines_b, pos_b - 1)}

    parse_diff(
      List.insert_at(lines, pos_a + offset_a, add_line),
      rest_diff,
      {pos_a + 1, offset_a, offset_modifier + 1},
      {lines_b, pos_b + 1}
    )
  end

  @cmd_regex ~r/([\d,]+)[acd]([\d,]+)/
  defp parse_diff(lines, [cmd | rest_diff], {_, offset_a, offset_modifier}, {lines_b, _}) do
    [a, b] = Regex.run(@cmd_regex, cmd, capture: :all_but_first)
    int_a = a |> String.split(",") |> Enum.at(0) |> String.to_integer()
    int_b = b |> String.split(",") |> Enum.at(0) |> String.to_integer()

    parse_diff(lines, rest_diff, {int_a, offset_a + offset_modifier, 0}, {lines_b, int_b})
  end
end
