defmodule Parser.Unify do
  defmodule ModuleInfo do
    defstruct [:name, :end_line, :defs]
  end

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

  def entry(file) do
    file_content = File.read!(file)
    file_lines = String.split(file_content, "\n")

    root_ast = Code.string_to_quoted!(file_content)

    case root_ast do
      {:defmodule, meta,
       [
         {:__aliases__, meta, [module_name]},
         [do: do_stuff]
       ]} ->
        root_module = %ModuleInfo{
          name: module_name,
          end_line: find_nonempty_line_before(file_lines, length(file_lines)),
          defs: []
        }

        blocks = list_do_block(do_stuff)

        parse([], blocks, nil, root_module, [])

      other ->
        IO.inspect(other)
    end
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
    parse(modules_left, [], nil, nil, [current_module | modules_acc])
  end

  # last `Defined` in a module
  def parse(modules_left, [], %Defined{} = df, current_module, modules_acc) do
    end_df = %{df | end_line: current_module.end_line - 1}

    new_module = save_defined(end_df, current_module)
    parse(modules_left, [], nil, new_module, modules_acc)
  end

  # @doc starts a new `current_df`
  def parse(
        modules_left,
        [{:@, [line: l], [{:doc, _, _}]} | block_left],
        nil,
        current_module,
        modules_acc
      ) do
    new_df = %Defined{start_line: l}

    parse(modules_left, block_left, new_df, current_module, modules_acc)
  end

  def parse(
        modules_left,
        [{:@, [line: l], [{:doc, _, _}]} | block_left],
        current_df,
        current_module,
        modules_acc
      ) do
    end_df = %{current_df | end_line: l - 1}
    new_module = save_defined(end_df, current_module)

    new_df = %Defined{start_line: l}

    parse(modules_left, block_left, new_df, new_module, modules_acc)
  end

  # @spec continues or starts a new `Defined`
  def parse(
        modules_left,
        [{:@, [line: l], [{:spec, _, _}]} | block_left],
        nil,
        current_module,
        modules_acc
      ) do
    new_df = %Defined{start_line: l}

    parse(modules_left, block_left, new_df, current_module, modules_acc)
  end

  def parse(
        modules_left,
        [{:@, [line: l], [{:spec, _, spec_b}]} | block_left],
        current_df,
        current_module,
        modules_acc
      ) do
    # TODO: check function name?
    # [{:::, _, [{df_name, _, _} | _]}]} = spec_b
    case current_df.name do
      nil ->
        # continue from @doc
        parse(modules_left, block_left, current_df, current_module, modules_acc)

      _ ->
        # function is named, ends `current_df` and start a new one
        end_df = %{current_df | end_line: l - 1}
        new_module = save_defined(end_df, current_module)

        new_df = %Defined{start_line: l}

        parse(modules_left, block_left, new_df, new_module, modules_acc)
    end
  end

  # def, defp, defmacro, defmacrop continues or starts a new `Defined`
  def parse(
        modules_left,
        [{:def, [line: l], [{df_name, _, args} | _]} | block_left],
        nil,
        current_module,
        modules_acc
      ) do
    new_df = %Defined{
      name: df_name,
      start_line: l,
      private?: false,
      arity: count_args(args)
    }

    parse(modules_left, block_left, new_df, current_module, modules_acc)
  end

  def parse(
        modules_left,
        [{:def, [line: l], [{df_name, _, args} | _]} | block_left],
        current_df,
        current_module,
        modules_acc
      ) do
    case current_df.name do
      ^df_name ->
        # same function name, continue
        parse(modules_left, block_left, current_df, current_module, modules_acc)

      _ ->
        # different name, starting a new `Defined`
        end_df = %{current_df | end_line: l - 1}
        new_module = save_defined(end_df, current_module)

        new_df = %Defined{
          name: df_name,
          start_line: l,
          private?: false,
          arity: count_args(args)
        }

        parse(modules_left, block_left, new_df, new_module, modules_acc)
    end
  end

  # defmodule updates modules_left

  ## private helpers
  defp save_defined(df, module) do
    case df.name do
      # incomplete definition
      nil -> module
      _ -> %{module | defs: [df | module.defs]}
    end
  end

  defp count_args(nil), do: 0
  defp count_args(args), do: length(args)

  defp list_do_block({:__block__, [], block}), do: block
  defp list_do_block(single_block), do: [single_block]

  defp find_nonempty_line_before(lines, lineno) do
    this_line = lines |> Enum.at(lineno - 1) |> String.trim()

    case this_line do
      "" -> find_nonempty_line_before(lines, lineno - 1)
      _ -> lineno
    end
  end
end
