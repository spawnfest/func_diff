defmodule ParserTest do
  use ExUnit.Case

  import Parser, only: [process: 1]

  describe "process/1" do
    test "single empty module" do
      actual = process("test/priv/single_empty_module.ex")

      assert [
               %Parser.ModuleInfo{
                 module_name: "SingleModule",
                 functions: [],
                 macros: []
               }
             ] = actual
    end

    test "multiple modules" do
      actual = process("test/priv/multiple_modules.ex")

      assert [%Parser.ModuleInfo{}, %Parser.ModuleInfo{}] = actual
    end

    test "nested modules" do
      actual = process("test/priv/nested_modules.ex")

      assert [
               %Parser.ModuleInfo{
                 module_name: "Outer"
               },
               %Parser.ModuleInfo{
                 module_name: "Outer.Inner"
               }
             ] = actual
    end

    test "one line function" do
      actual = process("test/priv/functions/one_line.ex")

      assert [
               %Parser.ModuleInfo{
                 functions: [
                   %Parser.FunctionInfo{
                     function_name: "one_line"
                   }
                 ]
               }
             ] = actual
    end

    test "module with a single function" do
      actual = process("test/priv/functions/single.ex")

      assert [
               %Parser.ModuleInfo{
                 functions: [
                   %Parser.FunctionInfo{
                     function_name: "single"
                   }
                 ]
               }
             ] = actual
    end

    test "normal module" do
      actual = process("test/priv/functions/normal.ex")

      assert [
               %Parser.ModuleInfo{
                 functions: [
                   %Parser.FunctionInfo{
                     function_name: "normal1"
                   },
                   %Parser.FunctionInfo{
                     function_name: "normal2"
                   }
                 ],
                 macros: [
                   %Parser.MacroInfo{
                     macro_name: "normal3"
                   }
                 ]
               }
             ] = actual
    end
  end
end
