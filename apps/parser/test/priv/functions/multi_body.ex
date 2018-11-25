defmodule FuncTest4 do
  def no_head(a, :ok) do
    :ok
  end

  def no_head(_, _) do
    :error
  end

  def with_head(a, b)

  def with_head(a, :ok) do
    :ok
  end

  def with_head(_, _), do: :error
end
