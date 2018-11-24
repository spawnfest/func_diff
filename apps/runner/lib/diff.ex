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

    result = Porcelain.exec(
      "diff",
      [file_a, file_b]
    )

    File.rm(file_a)
    File.rm(file_b)

    parse_result(result, text_a)
  end

  defp parse_result(%Porcelain.Result{status: 0, out: output}, base_text) do
    # TODO
  end
  defp parse_result(_, _), do: []
end
