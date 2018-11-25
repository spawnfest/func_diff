defmodule Parser.Unify do
  defmodule ModuleInfo do
    defstruct [:name, :end_line, :defs]
  end

  defmodule Defined do
    @type t() :: %__MODULE__{
            name: atom() | nil,
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

    defimpl Inspect do
      def inspect(df, _) do
        deco =
          if df.private? do
            "(priv)"
          else
            "(pub)"
          end

        "<#Definition #{df.name}/#{df.arity} #{deco} #{df.start_line} - #{df.end_line}>"
      end
    end
  end

  def process_file(file) do
    file_content = File.read!(file)
    file_lines = String.split(file_content, "\n")

    root_ast = Code.string_to_quoted!(file_content)

    case root_ast do
      {:defmodule, _,
       [
         {:__aliases__, _, names},
         [do: do_stuff]
       ]} ->
        module_name = stringify_module_name(names)

        root_module = %ModuleInfo{
          name: to_string(module_name),
          end_line: find_nonempty_line_before(file_lines, length(file_lines)),
          defs: []
        }

        block = list_do_block(do_stuff)

        parse(file_lines, [], block, nil, root_module, [])

      {:__block__, _, block} ->
        # create an empty module and let `parse` handle defmodule
        empty_module = %ModuleInfo{
          name: nil,
          end_line: length(file_lines)
        }

        parse(file_lines, [], block, nil, empty_module, [])
    end
  end

  # parse(file_lines, modules_left, block_left, current_defined, current_module, modules_acc)
  # modules_left is a list of { %ModuleInfo{}, block }

  # all things parsed
  def parse(_, [], [], nil, nil, modules_acc), do: modules_acc

  # more module to parse
  def parse(lines, [h | t], [], nil, nil, modules_acc) do
    {current_module, block} = h
    parse(lines, t, block, nil, current_module, modules_acc)
  end

  # module parsed
  def parse(lines, modules_left, [], nil, current_module, modules_acc) do
    case current_module.name do
      nil ->
        # empty module, ignored
        parse(lines, modules_left, [], nil, nil, modules_acc)

      _ ->
        parse(lines, modules_left, [], nil, nil, [current_module | modules_acc])
    end
  end

  # last `Defined` in a module
  def parse(lines, modules_left, [], %Defined{} = df, current_module, modules_acc) do
    end_df = %{df | end_line: find_nonempty_line_before(lines, current_module.end_line - 1)}

    new_module = save_defined(end_df, current_module)
    parse(lines, modules_left, [], nil, new_module, modules_acc)
  end

  # @doc starts a new `current_df`
  def parse(
        lines,
        modules_left,
        [{:@, [line: l], [{:doc, _, _}]} | block_left],
        nil,
        current_module,
        modules_acc
      ) do
    new_df = %Defined{start_line: l}

    parse(lines, modules_left, block_left, new_df, current_module, modules_acc)
  end

  def parse(
        lines,
        modules_left,
        [{:@, [line: l], [{:doc, _, _}]} | block_left],
        current_df,
        current_module,
        modules_acc
      ) do
    end_df = %{current_df | end_line: find_nonempty_line_before(lines, l - 1)}
    new_module = save_defined(end_df, current_module)

    new_df = %Defined{start_line: l}

    parse(lines, modules_left, block_left, new_df, new_module, modules_acc)
  end

  # @spec continues or starts a new `Defined`
  def parse(
        lines,
        modules_left,
        [{:@, [line: l], [{:spec, _, _}]} | block_left],
        nil,
        current_module,
        modules_acc
      ) do
    new_df = %Defined{start_line: l}

    parse(lines, modules_left, block_left, new_df, current_module, modules_acc)
  end

  def parse(
        lines,
        modules_left,
        [{:@, [line: l], [{:spec, _, _spec_b}]} | block_left],
        current_df,
        current_module,
        modules_acc
      ) do
    # TODO: check function name?
    # [{:::, _, [{df_name, _, _} | _]}]} = spec_b
    case current_df.name do
      nil ->
        # continue from @doc
        parse(lines, modules_left, block_left, current_df, current_module, modules_acc)

      _ ->
        # function is named, ends `current_df` and start a new one
        end_df = %{current_df | end_line: find_nonempty_line_before(lines, l - 1)}
        new_module = save_defined(end_df, current_module)

        new_df = %Defined{start_line: l}

        parse(lines, modules_left, block_left, new_df, new_module, modules_acc)
    end
  end

  # def, defp, defmacro, defmacrop continues or starts a new `Defined`
  @defcmds [:def, :defp, :defmacro, :defmacrop]
  def parse(
        lines,
        modules_left,
        [{cmd, [line: l], [{df_name, _, args} | _]} | block_left],
        nil,
        current_module,
        modules_acc
      )
      when cmd in @defcmds do
    new_df = %Defined{
      name: df_name,
      start_line: l,
      private?: cmd in [:defp, :defmacrop],
      arity: count_args(args)
    }

    parse(lines, modules_left, block_left, new_df, current_module, modules_acc)
  end

  def parse(
        lines,
        modules_left,
        [{cmd, [line: l], [{df_name, _, args} | _]} | block_left],
        current_df,
        current_module,
        modules_acc
      )
      when cmd in @defcmds do
    case current_df.name do
      ^df_name ->
        # same function name, continue
        parse(lines, modules_left, block_left, current_df, current_module, modules_acc)

      nil ->
        # conitnue from @doc or @spec, but fill in info
        updated_df = %{
          current_df
          | name: df_name,
            private?: cmd in [:defp, :defmacrop],
            arity: count_args(args)
        }

        parse(lines, modules_left, block_left, updated_df, current_module, modules_acc)

      _ ->
        # different name, starting a new `Defined`
        end_df = %{current_df | end_line: find_nonempty_line_before(lines, l - 1)}
        new_module = save_defined(end_df, current_module)

        new_df = %Defined{
          name: df_name,
          start_line: l,
          private?: cmd in [:defp, :defmacrop],
          arity: count_args(args)
        }

        parse(lines, modules_left, block_left, new_df, new_module, modules_acc)
    end
  end

  # defmodule updates modules_left
  def parse(
        lines,
        modules_left,
        [
          {:defmodule, _,
           [
             {:__aliases__, _, names},
             [do: do_stuff]
           ]}
        ],
        current_df,
        current_module,
        modules_acc
      ) do
    module_name = stringify_module_name(names)

    another_module = %ModuleInfo{
      name: nested_module_name(current_module.name, module_name),
      end_line: find_nonempty_line_before(lines, current_module.end_line - 1),
      defs: []
    }

    another_block = list_do_block(do_stuff)

    parse(
      lines,
      [{another_module, another_block} | modules_left],
      [],
      current_df,
      current_module,
      modules_acc
    )
  end

  def parse(
        lines,
        modules_left,
        [
          {:defmodule, _,
           [
             {:__aliases__, _, names},
             [do: do_stuff]
           ]}
          | [{_, [line: next_element_start_line], _} | _] = block_left
        ],
        current_df,
        current_module,
        modules_acc
      ) do
    module_name = stringify_module_name(names)

    another_module = %ModuleInfo{
      name: nested_module_name(current_module.name, module_name),
      end_line: find_nonempty_line_before(lines, next_element_start_line - 1),
      defs: []
    }

    another_block = list_do_block(do_stuff)

    parse(
      lines,
      [{another_module, another_block} | modules_left],
      block_left,
      current_df,
      current_module,
      modules_acc
    )
  end

  # ignore other AST constructs
  def parse(lines, modules_left, [_ | block_left], current_df, current_module, modules_acc) do
    parse(lines, modules_left, block_left, current_df, current_module, modules_acc)
  end

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

  defp nested_module_name(nil, name), do: name
  defp nested_module_name(parent, name), do: parent <> "." <> name

  defp stringify_module_name(names) do
    names
    |> Enum.map(&to_string/1)
    |> Enum.join(".")
  end
end
