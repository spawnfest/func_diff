defmodule Parser do
  @moduledoc false

  defmodule ModuleInfo do
    @type t() :: %__MODULE__{
            module_name: binary() | nil,
            line_number: integer() | nil,
            functions: list(FunctionInfo.t()),
            macros: list(MacroInfo.t())
          }
    defstruct(
      module_name: nil,
      line_number: nil,
      functions: [],
      macros: []
    )
  end

  defmodule FunctionInfo do
    @type t() :: %__MODULE__{
            function_name: binary() | nil,
            line_number: integer() | nil
          }
    defstruct(
      function_name: nil,
      line_number: nil
    )
  end

  defmodule MacroInfo do
    @type t() :: %__MODULE__{
            macro_name: binary() | nil,
            line_number: integer(),
          }
    defstruct(
      macro_name: nil,
      line_number: nil
    )
  end

  @spec process(binary()|list()) :: list(ModuleInfo.t())
  def process(file_paths) when is_list(file_paths), do:
    file_paths
    |> Enum.map(&process/1)
  def process(file_path), do: parse_file(file_path)

  defp parse_file(file),
    do:
      file
      |> File.read!()
      |> Code.string_to_quoted!()
      |> parse()
      |> List.flatten()

  # parse module info and nested module info when encounters {:defmodule, _, _})
  defp parse(module_info, parent_module \\ nil)
  defp parse(list, parent_module) when is_list(list), do: Enum.map(list, &parse(&1, parent_module))
  defp parse({:defmodule, meta, module}, parent_module) do
    block = extract_do_block(module)
    module_info = block
    |> extract_functions(%ModuleInfo{})
    |> extract_macros(block)
    |> Map.put(:module_name, parent_module)
    |> Map.put(:line_number, Keyword.get(meta, :line))
    |> extract_module_name(module)
    [module_info] ++ parse(block, module_info.module_name)
  end
  defp parse({_, [], list}, parent_module), do: Enum.map(list, &parse(&1, parent_module))
  defp parse(_, _), do: []

  # get module name from the aliases block if on the same line as defmodule
  defp extract_module_name(module_info = %{line_number: line_number}, [{:__aliases__, meta, names}|_t]), do:
    update_module_name(module_info, names, Keyword.get(meta, :line) == line_number)

  defp extract_module_name(module_info, [_h|t]), do: extract_module_name(module_info, t)

  defp extract_do_block([]), do: []
  defp extract_do_block([h|_t]) when is_list(h), do: extract_do_block(h)
  defp extract_do_block([{:do, {:__block__, [], block}}|_]), do: block
  defp extract_do_block([_|t]), do: extract_do_block(t)

  defp extract_functions([], module_info = %{functions: functions}), do:
    %{module_info|functions: Enum.sort(functions, fn(a, b) -> a.line_number < b.line_number end)}
  defp extract_functions([{:def, meta, func_info}|t], module_info = %{functions: functions}) do
    function = parse_function(func_info, %FunctionInfo{line_number: Keyword.get(meta, :line)})
    extract_functions(t, %{module_info|functions: [function|functions]})
  end
  defp extract_functions([{:defp, meta, func_info}|t], module_info = %{functions: functions}) do
    function = parse_function(func_info, %FunctionInfo{line_number: Keyword.get(meta, :line)})
    extract_functions(t, %{module_info|functions: [function|functions]})
  end
  defp extract_functions([_|t], module_info), do: extract_functions(t, module_info)

  defp extract_macros(module_info, []), do: module_info
  defp extract_macros(module_info = %{macros: macros}, [{:defmacro, meta, macro_info}|t]) do
    macro = parse_macro(macro_info, %MacroInfo{line_number: Keyword.get(meta, :line)})
    extract_macros(%{module_info|macros: [macro|macros]}, t)
  end
  defp extract_macros(module_info, [_|t]), do: extract_macros(module_info, t)

  # prepend parent module name if there exists any
  defp update_module_name(module_info = %{module_name: nil}, names, true), do:
    %{module_info|module_name: Enum.join(names, ".")}
  defp update_module_name(module_info = %{module_name: prefix}, names, true), do:
    %{module_info|module_name: prefix <> "." <> Enum.join(names, ".")}
  defp update_module_name(module_info, _names, false), do: module_info

  # obtain function name from the same line as def/defp
  defp parse_function([{name, meta, _args_info}|_t], func_info = %{line_number: line_number}) do
    case Keyword.get(meta, :line) == line_number do
      true -> %{func_info|function_name: name}
      false -> func_info
    end
  end

  defp parse_macro([{name, meta, _}|_t], macro_info = %{line_number: line_number}) do
    case Keyword.get(meta, :line) == line_number do
      true -> %{macro_info|macro_name: Atom.to_string(name)}
      false -> macro_info
    end
  end
end