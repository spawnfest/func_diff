defmodule ParserTest do
  use ExUnit.Case

  import Parser, only: [process: 1]

  describe "process" do
    test "single empty module" do
      expected = [
        %Parser.ModuleInfo{
          module_name: "SingleModule",
          start_line: 1,
          functions: [],
          macros: []
        }
      ]

      assert expected == process("test/priv/single_empty_module.ex")
    end
  end
end
