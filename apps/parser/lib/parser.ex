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
            functions: FunctionInfo.t()
          }
    defstruct(
      macro_name: nil,
      line_number: nil,
      functions: []
    )
  end

  @spec process(charlist()) :: list(ModuleInfo.t())
  def process(relative_path \\ './') do
    # TODO: to be replaced by elixirc_paths
    files = Utils.Finder.find_all(relative_path)

    files
    |> Enum.map(&parse_file/1)
  end

  defp parse_file(file_name),
    do:
      file_name
      |> File.read!()
      |> Code.string_to_quoted!()
      |> parse()

  # parse module info and nested module info when encounters {:defmodule, _, _}
  defp parse(module_info, parent_module \\ nil)
  defp parse({:defmodule, meta, module}, parent_module) do
    module_info = %ModuleInfo{module_name: parent_module, line_number: Keywords.get(meta, :line)}
    parse_module(module_info, module) ++ parse(module, parent_module)
  end
  defp parse({_, [], list}, parent_module), do: Enum.map(list, &parse(&1, parent_module))

  # parse module info
  defp parse_module(list, module_info) when is_list(list),
    do: Enum.reduce(list, module_info, &parse_module/2)

  # get module name from the aliases block on the same line as defmodule
  defp parse_module(module_info, [{:__aliases__, meta, names}|t]) do
    new_module_info = update_module_name(module_info, names, Keywords.geT(meta, :line) == module_info[:line_number])
    parse_module(new_module_info, t)
  end
  defp parse_module(parent_module, module_info, [h|t]), do: parse_module(parent_module, module_info, t)

  defp update_module_name(module_info = %{module_name: nil}, names, true), do:
    %{module_info|module_name: Enum.join(names, ".")}
  defp update_module_name(module_info = %{module_name: prefix}, names, true), do:
    %{module_info|module_name: prefix <> "." <> Enum.join(names, ".")}

end
