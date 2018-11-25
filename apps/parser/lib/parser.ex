defmodule Parser do
  @moduledoc false

  # @spec process(binary() | list()) :: list(Parser.Unify.ModuleInfo.t())
  def process(file_paths) when is_list(file_paths),
    do:
      file_paths
      |> Enum.flat_map(&process/1)

  def process(file_path), do: Parser.Unify.process_file(file_path)
end
