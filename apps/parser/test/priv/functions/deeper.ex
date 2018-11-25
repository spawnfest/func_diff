defmodule FuncTest5 do
  def deeper(a, b) do
    if a == b do
      case b do
        :ok -> :ok
        _ -> a
      end
    end
  end
end
