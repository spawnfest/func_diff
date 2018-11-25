defmodule Parser do
  @moduledoc false

  alias Parser.ASTParser

  defmodule ModuleInfo do
    @type t() :: %__MODULE__{
            module_name: binary() | nil,
            start_line: integer() | nil,
            functions: list(FunctionInfo.t()),
            macros: list(MacroInfo.t())
          }
    defstruct(
      module_name: nil,
      start_line: nil,
      functions: [],
      macros: []
    )
  end

  defmodule FunctionInfo do
    @type t() :: %__MODULE__{
            function_name: binary() | nil,
            start_line: integer() | nil,
            end_line: integer() | nil,
            arity: integer() | nil,
            private?: boolean()
          }
    defstruct(
      function_name: nil,
      start_line: nil,
      end_line: nil,
      arity: nil,
      private?: false
    )
  end

  defmodule MacroInfo do
    @type t() :: %__MODULE__{
            macro_name: binary() | nil,
            start_line: integer(),
            end_line: integer()
          }
    defstruct(
      macro_name: nil,
      start_line: nil,
      end_line: nil
    )
  end

  @spec process(binary() | list()) :: list(ModuleInfo.t())
  def process(file_paths) when is_list(file_paths),
    do:
      file_paths
      |> Enum.flat_map(&process/1)

  def process(file_path), do: parse_file(file_path)

  defp parse_file(file),
    do:
      file
      |> File.read!()
      |> Code.string_to_quoted!()
      |> ASTParser.parse()
      |> List.flatten()
      #|> SourceParser.ajust()
end
