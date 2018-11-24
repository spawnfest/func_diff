defmodule Runner.Mix do
  @moduledoc """
  Execute `mix` commands. Currently only to extract `elixirc_paths` and `erlc_paths`
  from a project's `mix.exs` file.
  """

  def elixirc_paths(mix_file) do
    with {:ok, content} <- File.read(mix_file),
         {:ok, ast} <- Code.string_to_quoted(content),
         name <- find_project_name(ast),
         cmd <- elixirc_paths_cmd(name),
         {:ok, paths} when is_list(paths) <- extract_path(cmd, mix_file) do
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

  def erlang_paths(mix_file) do
    with {:ok, content} <- File.read(mix_file),
         {:ok, ast} <- Code.string_to_quoted(content),
         name <- find_project_name(ast),
         cmd <- erlc_paths_cmd(name),
         {:ok, paths} when is_list(paths) <- extract_path(cmd, mix_file) do
      if Enum.all?(paths, &is_binary/1) do
        paths ++ ["include"]
      else
        ["src", "include"]
      end
    else
      # try default Elixir source code path
      _ -> ["src", "include"]
    end
  end

  defp find_project_name(ast), do: do_fpn(ast, [])

  defp do_fpn({:defmodule, _, [{:__aliases__, _, names} | _]}, _) do
    names
    |> Enum.map(&to_string/1)
    |> Enum.join(".")
  end

  defp do_fpn({_, _, [h | t]}, acc), do: do_fpn(h, acc ++ t)
  defp do_fpn(_, [h | t]), do: do_fpn(h, t)
  defp do_fpn(_, []), do: {:error, :no_project}

  defp elixirc_paths_cmd(name) do
    name <> ".project[:elixirc_paths] |> IO.inspect"
  end

  defp erlc_paths_cmd(name) do
    name <> ".project[:erlc_paths] |> IO.inspect"
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

  @doc """
  Reads a `mix_file` and uses its `elixirc_paths` and `erlc_paths` to list all source files.

  Returns a tuple of two lists, first list contains Elixir source files, and second list
  contains Erlang source files.
  """
  def list_source_files(mix_file) do
    project_path = Path.dirname(mix_file)

    ex_paths = elixirc_paths(mix_file)
    |> Enum.join(",")

    erl_paths = erlang_paths(mix_file)
    |> Enum.join(",")

    {
      Path.wildcard(project_path <> "/{" <> ex_paths <> "}/**/*.ex"),
      Path.wildcard(project_path <> "/{" <> erl_paths <> "}/**/*.{erl,hrl}")
    }
  end
end
