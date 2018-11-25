defmodule Interactive do
  @moduledoc """
  An interactive FuncDiff experience.
  """

  defmodule Token do
    defstruct [:pid]

    defimpl Inspect do
      def inspect(token, _) do
        "<Token #{:erlang.phash2(token.pid)}>"
      end
    end
  end

  alias FuncDiffAPI.ComparisonActor, as: CA

  @opaque token() :: Token.t()

  @doc """
  Start a new process to diff a given `github` repo, comparing `target` to `base`.

  The repo should be in "user/repo" format, `base` and `target` can be any valid
  git reference (branch, tag, commit hash). All arguments should be of Elixir String
  type.
  """
  @spec new_diff(String.t(), String.t(), String.t()) :: token()
  def new_diff(github, base, target) do
    {:ok, pid} = CA.start_link(github: github, base_ref: base, target_ref: target)

    %Token{pid: pid}
  end

  @doc """
  List differences at modules (project) level
  """
  def modules(%Token{} = token) do
    token.pid
    |> CA.get_state()
    |> Map.get(:modules_diff)
    |> Enum.sort_by(fn {_, name} -> name end)
    |> print_diff()
  end

  def modules(_), do: {:error, :invalid_token}

  @doc """
  List differences at a single module's level
  """
  def module(%Token{} = token, module) when is_binary(module) do
    token.pid
    |> CA.get_state()
    |> Map.get(:module_diff)
    |> Map.get(module)
    |> print_diff()
  end

  def module(_, _), do: {:error, :invalid_token}

  @doc """
  List diff of a single function/macro
  """
  def func(%Token{} = token, module, func) when is_binary(module) do
    token.pid
    |> CA.get_state()
    |> Map.get(:func_diff)
    |> Map.get({module, func})
    |> print_diff()
  end

  def func(_, _, _), do: {:error, :invalid_token}

  @help """

  Start a new diff with `new_diff`, check its doc with `h new_diff`. Use the
  returned "token" (referenced as `t` below) to read diff interactively.

  Then use:

    - `modules(t)` to list module diff
    - `module(t, module_name)` to list func diff within a module
    - `func(t, module_name, func_id)` to show source code diff for a given function
    (or macro)
    - `semver_check(t)` to check if the semver change aligns with the semver specifications

  Note both `module_name` and `func_id` needs to be Elixir String. `func_id` is of
  the format "function_name/arity", like "diff/3".

  The diff output uses color and leading symbol to indicate type of change, like below:
  """
  def func_diff_help() do
    IO.puts(@help)

    [
      {:add, "this is an added line"},
      {:del, "this is a deleted line"},
      {:change, "this indicates a changed module or func"},
      {:common, "this means it's not changed"}
    ]
    |> print_diff()

    IO.puts("Enjoy Func Diff'ing!")
    IO.puts("")
  end

  @doc """
  Check if the changes follow semver convention
  """
  def semver_check(%Token{} = token) do
    state = CA.get_state(token.pid)
    semver_change = get_semver_change(state.base_ref, state.target_ref)

    state
    |> Map.get(:degree_of_change)
    |> check_semver(semver_change)
  end

  ## debug helpers

  def debug_state(%Token{} = token) do
    CA.get_state(token.pid)
  end

  defp print_diff(diff) do
    Enum.each(diff, fn
      {:add, line} ->
        IO.ANSI.format([:light_green_background, :black, deco_line("+", line)]) |> IO.puts()

      {:del, line} ->
        IO.ANSI.format([:light_black_background, :light_cyan, deco_line("-", line)]) |> IO.puts()

      {:change, line} ->
        IO.ANSI.format([:light_blue_background, :white, deco_line("!", line)]) |> IO.puts()

      {:common, line} ->
        deco_line(" ", line) |> IO.puts()
    end)
  end

  defp deco_line(deco, line, pad \\ 80) do
    (deco <> " " <> line)
    |> String.pad_trailing(pad)
  end

  defp check_semver(change, change), do: {:ok, :valid_semver_change}
  defp check_semver(expected, changed), do: {:warning, "expected :#{expected}, got :#{changed}"}

  defp get_semver_change(base_ref, target_ref),
    do: get_semver_change(String.split(base_ref, "."), String.split(target_ref, "."), :major)

  defp get_semver_change([], [], _), do: :semver_not_changed
  defp get_semver_change([n | tb], [n | tt], change), do: get_semver_change(tb, tt, next(change))
  defp get_semver_change(_, _, change), do: change

  defp next(:major), do: :minor
  defp next(:minor), do: :patch
end
