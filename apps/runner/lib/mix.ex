defmodule Runner.Mix do
  @moduledoc """
  Execute `mix` commands. Currently only to extract `elixirc_paths` and `erlc_paths`
  from a project's `mix.exs` file.
  """

  def elixic_paths(mix_file) do
    with {:ok, content} <- File.read(mix_file),
         {:ok, ast} <- Code.string_to_quoted(content),
         {:defmodule, _, [{:__aliases__, _, names} | _]} <- ast,
         cmd <- elixirc_paths_cmd(names),
         paths when is_list(paths) <- extract_path(cmd, mix_file) do
      if Enum.all?(paths, &is_binary/1) do
        paths
      else
        ["lib"]
      end
    else
      # try default Elixir source code path
      _ -> ["lib"]
    end
  end

  def erlc_paths(mix_file) do
    with {:ok, content} <- File.read(mix_file),
         {:ok, ast} <- Code.string_to_quoted(content),
         {:defmodule, _, [{:__aliases__, _, names} | _]} <- ast,
         cmd <- erlc_paths_cmd(names),
         paths when is_list(paths) <- extract_path(cmd, mix_file) do
      if Enum.all?(paths, &is_binary/1) do
        paths
      else
        ["src"]
      end
    else
      # try default Elixir source code path
      _ -> ["src"]
    end
  end

  defp elixirc_paths_cmd(names) do
    names
    |> Enum.map(&to_string/1)
    |> Enum.join(".")
    |> Kernel.<>(".project[:elixirc_paths] |> IO.inspect")
  end

  defp erlc_paths_cmd(names) do
    names
    |> Enum.map(&to_string/1)
    |> Enum.join(".")
    |> Kernel.<>(".project[:erlc_paths] |> IO.inspect")
  end

  defp extract_path(cmd, mix_file) do
    case Porcelain.exec(
           "mix",
           ["run", "--no-start", "--no-deps-check", "--no-compile", "-e", cmd],
           dir: Path.dirname(mix_file)
         ) do
      %Porcelain.Result{status: 0, out: out} ->
        out
        |> String.trim()
        |> Code.string_to_quoted()

      %Porcelain.Result{err: err} ->
        {:error, err}

      _ ->
        {:error, :unknown}
    end
  end
end
