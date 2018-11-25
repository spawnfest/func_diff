defmodule FuncTest.Module7 do
  @moduledoc false

  @some_attr 123

  @doc "hello"
  @spec normal1() :: :ok
  def normal1 do
    :ok
  end

  def normal2 do
    :ok
  end

  defmacro normal3 do
    :ok
  end
end
