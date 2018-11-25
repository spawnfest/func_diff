defmodule FuncTest10 do
  def with_guard(a) when is_binary(a), do: :ok

  def with_guard(a)
      when is_integer(a) and a > 2 do
    :integer
  end

  def with_guard(_) do
    :sure
  end
end
