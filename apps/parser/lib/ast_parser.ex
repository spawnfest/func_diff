defmodule Parser.ASTParser do
  @moduledoc false

  # parse module info and nested module info when encounters {:defmodule, _, _})
  def parse(module_info, parent_module \\ nil)

  def parse(list, parent_module) when is_list(list),
    do: Enum.map(list, &parse(&1, parent_module))

  def parse({:defmodule, meta, module}, parent_module) do
    IO.inspect module
    block = extract_do_block(module)

    module_info =
      block
      |> extract_functions(%Parser.ModuleInfo{})
      |> extract_macros(block)
      |> Map.put(:module_name, parent_module)
      |> Map.put(:start_line, Keyword.get(meta, :line))
      |> extract_module_name(module)

    [module_info] ++ parse(block, module_info.module_name)
  end

  def parse({_, [], list}, parent_module), do: Enum.map(list, &parse(&1, parent_module))
  def parse(_, _), do: []

  # get module name from the aliases block if on the same line as defmodule
  defp extract_module_name(module_info = %{start_line: start_line}, [
         {:__aliases__, meta, names} | _t
       ]),
       do: update_module_name(module_info, names, Keyword.get(meta, :line) == start_line)

  defp extract_module_name(module_info, [_h | t]), do: extract_module_name(module_info, t)

  defp extract_do_block([]), do: []
  defp extract_do_block([h | _t]) when is_list(h), do: extract_do_block(h)
  defp extract_do_block([{:do, {:__block__, [], block}} | _]), do: block
  defp extract_do_block([{:do, block}]), do: [block]
  defp extract_do_block([_ | t]), do: extract_do_block(t)

  defp extract_functions([], module_info = %{functions: functions}),
    do: %{
      module_info
      | functions: Enum.sort(functions, fn a, b -> a.start_line < b.start_line end)
    }

  defp extract_functions([{:def, meta, func_info} | t], module_info = %{functions: functions}) do
    function = parse_function(func_info, %Parser.FunctionInfo{start_line: Keyword.get(meta, :line), private?: false})

    extract_functions(t, %{module_info | functions: [function | update_end_line(meta, functions)]})
  end

  defp extract_functions([{:defp, meta, func_info} | t], module_info = %{functions: functions}) do
    function = parse_function(func_info, %Parser.FunctionInfo{start_line: Keyword.get(meta, :line), private?: true})

    extract_functions(t, %{module_info | functions: [function | update_end_line(meta, functions)]})
  end

  defp extract_functions([{_, meta, _} | t], module_info = %{functions: functions}),
    do: extract_functions(t, %{module_info | functions: update_end_line(meta, functions)})

  defp extract_functions([_ | t], module_info), do: extract_functions(t, module_info)

  defp update_end_line(_meta, []), do: []

  defp update_end_line(meta, [function | t]),
    do: [%{function | end_line: Keyword.get(meta, :line)} | t]

  defp extract_macros(module_info, []), do: module_info

  defp extract_macros(module_info = %{macros: macros}, [{:defmacro, meta, macro_info} | t]) do
    macro = parse_macro(macro_info, %Parser.MacroInfo{start_line: Keyword.get(meta, :line)})
    extract_macros(%{module_info | macros: [macro | macros]}, t)
  end

  defp extract_macros(module_info, [_ | t]), do: extract_macros(module_info, t)

  # prepend parent module name if there exists any
  defp update_module_name(module_info = %{module_name: nil}, names, true),
    do: %{module_info | module_name: Enum.join(names, ".")}

  defp update_module_name(module_info = %{module_name: prefix}, names, true),
    do: %{module_info | module_name: prefix <> "." <> Enum.join(names, ".")}

  defp update_module_name(module_info, _names, false), do: module_info

  # obtain function name from the same line as def/defp
  defp parse_function([{name, meta, args_info} | _t], func_info = %{start_line: start_line}) do
    case Keyword.get(meta, :line) == start_line do
      true -> %{func_info | function_name: Atom.to_string(name), arity: extract_arity(args_info)}
      false -> func_info
    end
  end

  defp extract_arity(nil), do: 0
  defp extract_arity(args), do: Enum.count(args)

  defp parse_macro([{name, meta, _} | _t], macro_info = %{start_line: start_line}) do
    case Keyword.get(meta, :line) == start_line do
      true -> %{macro_info | macro_name: Atom.to_string(name)}
      false -> macro_info
    end
  end
end