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
    |> print_diff()
  end

  def modules(_), do: {:error, :invalid_token}

  @doc """
  List differences at a single module's level
  """
  def module(%Token{} = _token, module) do
  end

  def module(_, _), do: {:error, :invalid_token}

  @doc """
  List diff of a single function/macro
  """
  def func(%Token{} = _token, module, func) do
  end

  def func(_, _, _), do: {:error, :invalid_token}

  ## debug helpers

  def debug_state(%Token{} = token) do
    CA.get_state(token.pid)
  end

  def debug_print() do
    [
      {:add, "line0"},
      {:common, "line1"},
      {:common, "line2"},
      {:del, "line3"},
      {:add, "line4"},
      {:common, "line5"},
      {:del, "line6"}
    ]
    |> print_diff()
  end

  defp print_diff(diff) do
    Enum.each(diff, fn
      {:add, line} ->
        IO.ANSI.format([:light_green_background, :black, deco_line("+", line)]) |> IO.puts()

      {:del, line} ->
        IO.ANSI.format([:light_black_background, :light_cyan, deco_line("-", line)]) |> IO.puts()

      # TODO: changed, "! "

      {:common, line} ->
        deco_line(" ", line) |> IO.puts()
    end)
  end

  defp deco_line(deco, line, pad \\ 80) do
    (deco <> " " <> line)
    |> String.pad_trailing(pad)
  end
end
