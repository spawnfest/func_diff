defmodule ParserTest do
  use ExUnit.Case

  import Parser, only: [process: 1]

  describe "process" do
    test "single empty module" do
      assert [
               %Parser.ModuleInfo{
                 module_name: "SingleModule",
                 functions: [],
                 macros: []
               }
             ] = process("test/priv/single_empty_module.ex")
    end

    test "multiple modules" do
      assert [%Parser.ModuleInfo{}, %Parser.ModuleInfo{}] =
               process("test/priv/multiple_modules.ex")
    end

    test "nested modules" do
      expected = [
        %Parser.ModuleInfo{
          module_name: "Outer",
          start_line: 1,
          functions: [],
          macros: []
        },
        %Parser.ModuleInfo{
          module_name: "Outer.Inner",
          start_line: 2,
          functions: [],
          macros: []
        }
      ]

      assert expected == process("test/priv/nested_modules.ex")
    end
  end
end
