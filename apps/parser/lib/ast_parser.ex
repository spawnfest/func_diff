defmodule Parser.ASTParser do
  @moduledoc false

  # parse module info and nested module info when encounters {:defmodule, _, _})
  def parse(module_info, source, parent_module \\ nil)

  def parse(list, source, parent_module) when is_list(list),
    do: Enum.map(list, &parse(&1, source, parent_module))

  def parse({:defmodule, meta, module}, source, parent_module) do
    IO.inspect module
    block = extract_do_block(module)
    start_line = Keyword.get(meta, :line)

    module_info =
      block
      |> extract_functions(%Parser.ModuleInfo{})
      |> extract_macros(block)
      |> Map.put(:module_name, parent_module)
      |> Map.put(:start_line, start_line)
      
    module_name = extract_module_name(module)
    end_line = extract_module_endline(module_name, source, start_line)
    module_info = update_module_name(module_info, module_name)

    module_info = %{module_info|end_line: end_line, functions: update_end_line(module_info, end_line - 1)}

    [module_info] ++ parse(block, source, module_info.module_name)
  end

  def parse({_, [], list}, source, parent_module, source_end_pointer), do:
    Enum.map(list, &parse(&1, source, parent_module, source_end_pointer))
  def parse(_, _, _, _), do: []

  # get module name from the aliases block if on the same line as defmodule
  defp extract_module_name(module_info = %{start_line: start_line}, [
         {:__aliases__, meta, names} | _t
       ]) do
    case Keyword.get(meta, :line) == start_line do
      true -> Enum.join(names, ".")
      false -> nil
    end       
  end

  defp extract_module_name(module_info, [_h | t]), do: extract_module_name(module_info, t)

  defp extract_do_block([]), do: []
  defp extract_do_block([h | _t]) when is_list(h), do: extract_do_block(h)
  defp extract_do_block([{:do, {:__block__, [], block}} | _]), do: block
  defp extract_do_block([{:do, block}]), do: [block]
  defp extract_do_block([_ | t]), do: extract_do_block(t)

  defp extract_functions([], module_info),
    do: module_info

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

  defp update_end_line(_, []), do: []

  defp update_end_line(end_line, [function | t]), do:
    [%{function | end_line: end_line} | t]

  defp update_end_line(meta, [function | t]),
    do: [%{function | end_line: Keyword.get(meta, :line) - 1} | t]

  defp extract_macros(module_info, []), do: module_info

  defp extract_macros(module_info = %{macros: macros}, [{:defmacro, meta, macro_info} | t]) do
    macro = parse_macro(macro_info, %Parser.MacroInfo{start_line: Keyword.get(meta, :line)})
    extract_macros(%{module_info | macros: [macro | macros]}, t)
  end

  defp extract_macros(module_info, [_ | t]), do: extract_macros(module_info, t)

  # prepend parent module name if there exists any
  defp update_module_name(module_info = %{module_name: nil}, module_name),
    do: %{module_info | module_name: module_name}

  defp update_module_name(module_info = %{module_name: prefix}, module_name),
    do: %{module_info | module_name: prefix <> "." <> module_name}

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

  defp extract_module_endline(module_name, source, start_line) do
    module_definition = Enum.at(source, start_line - 1)
    indentation = get_indentation(String.to_charlist(module_definition), "")
    next_module_startline = find_next_module(:lists.nthtail(, source), indentation <> "defmodule")
  end

  defp get_indentation([?\s|_], n), do: "\s" <> n
  defp get_indentation(_, n), do: n
end
