defmodule ParserTest do
  use ExUnit.Case

  import Parser, only: [process: 1]

  describe "process/1 on modules |" do
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
  end

  describe "process/1 on functions |" do
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

    test "doc_spec" do
      actual = process("test/priv/functions/doc_spec.ex")

      assert [
               %Parser.ModuleInfo{
                 functions: [
                   %Parser.FunctionInfo{
                     function_name: "doc_spec",
                     start_line: 2,
                     end_line: 6
                   }
                 ]
               }
             ] = actual
    end

    test "optional arg" do
      actual = process("test/priv/functions/optional_arg.ex")

      assert [
               %Parser.ModuleInfo{
                 functions: [
                   %Parser.FunctionInfo{
                     function_name: "optional"
                     # arity: 3
                   }
                 ]
               }
             ] = actual
    end

    test "multi body" do
      actual = process("test/priv/functions/multi_body.ex")

      assert [
               %Parser.ModuleInfo{
                 functions: [
                   %Parser.FunctionInfo{
                     function_name: "no_head",
                     start_line: 2,
                     end_line: 8
                   },
                   %Parser.FunctionInfo{
                     function_name: "with_head",
                     start_line: 10,
                     end_line: 16
                   }
                 ]
               }
             ] = actual
    end

    test "deep function" do
      actual = process("test/priv/functions/deeper.ex")

      assert [
               %Parser.ModuleInfo{
                 functions: [
                   %Parser.FunctionInfo{
                     function_name: "deeper",
                     start_line: 2,
                     end_line: 9
                   }
                 ]
               }
             ] = actual
    end
  end
end
