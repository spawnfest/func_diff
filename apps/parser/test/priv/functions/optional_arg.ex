defmodule FuncTest3 do
  def optional(_a, _b, _c \\ []) do
    :ok
  end
end
