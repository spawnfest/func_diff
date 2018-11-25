defmodule Parser.Unify do
  alias Parser.ModuleInfo

  defmodule Defined do
    @type t() :: %__MODULE__{
      name: binary() | nil,
      start_line: integer() | nil,
      end_line: integer() | nil,
      arity: integer() | nil,
      private?: boolean()
    }
    defstruct(
      name: nil,
      start_line: nil,
      end_line: nil,
      arity: nil,
      private?: false
    )
  end

  # parse(modules_left, block_left, current_defined, current_module, modules_acc)
  # modules_left is a list of { %ModuleInfo{}, block }

  # all things parsed
  def parse([], [], nil, nil, modules_acc), do: modules_acc

  # more module to parse
  def parse([h | t], [], nil, nil, modules_acc) do
    {current_module, block} = h
    parse(t, block, nil, current_module, modules_acc)
  end

  # module parsed
  def parse(modules_left, [], nil, current_module, modules_acc) do
    parse(modules_left, [], nil, nil, [ current_module | modules_acc ])
  end

  # last `Defined` in a module
  def parse(modules_left, [], %Defined{} = df, current_module, modules_acc) do
    end_df = %{df | end_line: current_module.end_line - 1}

    new_module = %{current_module | functions: [end_df | current_module.functions]}

    parse(modules_left, [], nil, new_module, modules_acc)
  end

  # @doc starts a new `current_df`
  def parse(modules_left, [{:@, [line: l], [{:doc, _, _}]} | block_left], nil, current_module, modules_acc) do

  end

  def parse(modules_left, [{:@, [line: l], [{:doc, _, _}]} | block_left], current_df, current_module, modules_acc) do
  end


  # @spec continues or starts a new `Defined`


  # def, defp, defmacro, defmacrop continues or starts a new `Defined`


  # defmodule updates modules_left







  ## private helpers
  defp get_line(meta), do: Keyword.get(meta, :line)
end
