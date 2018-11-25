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

  def modules(%Token{} = _token) do
  end

  def modules(_), do: {:error, :invalid_token}

  ## debug helpers

  def debug_state(%Token{} = token) do
    CA.get_state(token.pid)
  end

  def debug_print() do
    diff = [
      {:add, "line0"},
      {:common, "line1"},
      {:common, "line2"},
      {:del, "line3"},
      {:add, "line4"},
      {:common, "line5"},
      {:del, "line6"}
    ]

    Enum.each(diff, fn
      {:add, line} ->
        IO.ANSI.format([:light_green_background, :black, "+ " <> line]) |> IO.puts()

      {:del, line} ->
        IO.ANSI.format([:light_black_background, :light_cyan, "- " <> line]) |> IO.puts()

      {:common, line} ->
        IO.puts("  " <> line)
    end)
  end
end
