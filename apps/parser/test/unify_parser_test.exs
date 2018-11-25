defmodule Parser.UnifyTest do
  use ExUnit.Case

  import Parser.Unify, only: [process_file: 1]

  alias Parser.Unify.{ModuleInfo, Defined}

  describe "process_file/1 on modules |" do
    test "single empty module" do
      actual = process_file("test/priv/single_empty_module.ex")

      assert [
               %ModuleInfo{
                 name: "SingleModule",
                 defs: []
               }
             ] = actual
    end

    test "multiple modules" do
      actual = process_file("test/priv/multiple_modules.ex")

      assert [%ModuleInfo{name: "Module1"}, %ModuleInfo{name: "Module.Test2"}] = actual
    end

    test "nested modules" do
      actual = process_file("test/priv/nested_modules.ex")

      assert [
               %ModuleInfo{
                 name: "Outer.Inner"
               },
               %ModuleInfo{
                 name: "Outer"
               }
             ] = actual
    end
  end

  describe "process/1 on functions |" do
    test "one line function" do
      actual = process_file("test/priv/functions/one_line.ex")

      assert [
               %ModuleInfo{
                 defs: [
                   %Defined{
                     name: :one_line,
                     start_line: 2,
                     end_line: 2,
                     arity: 0,
                     private?: false
                   }
                 ]
               }
             ] = actual
    end

    test "module with a single function" do
      actual = process_file("test/priv/functions/single.ex")

      assert [
               %ModuleInfo{
                 defs: [
                   %Defined{
                     name: :single,
                     start_line: 2,
                     end_line: 4,
                     arity: 0,
                     private?: true
                   }
                 ]
               }
             ] = actual
    end

    test "normal module" do
      actual = process_file("test/priv/functions/normal.ex")

      assert [
               %ModuleInfo{
                 defs: [
                   %Defined{
                     name: :normal3,
                     start_line: 16,
                     end_line: 18,
                     arity: 0,
                     private?: false
                   },
                   %Defined{
                     name: :normal2,
                     start_line: 12,
                     end_line: 14,
                     arity: 0,
                     private?: false
                   },
                   %Defined{
                     name: :normal1,
                     start_line: 6,
                     end_line: 10,
                     arity: 0,
                     private?: false
                   }
                 ]
               }
             ] = actual
    end

    test "doc_spec" do
      actual = process_file("test/priv/functions/doc_spec.ex")

      assert [
               %ModuleInfo{
                 defs: [
                   %Defined{
                     name: :doc_spec,
                     start_line: 2,
                     end_line: 6,
                     arity: 0,
                     private?: false
                   }
                 ]
               }
             ] = actual
    end

    test "optional arg" do
      actual = process_file("test/priv/functions/optional_arg.ex")

      assert [
               %ModuleInfo{
                 defs: [
                   %Defined{
                     name: :optional,
                     start_line: 2,
                     end_line: 4,
                     arity: 3,
                     private?: false
                   }
                 ]
               }
             ] = actual
    end

    test "multi body" do
      actual = process_file("test/priv/functions/multi_body.ex")

      assert [
               %ModuleInfo{
                 defs: [
                   %Defined{
                     name: :with_head,
                     start_line: 10,
                     end_line: 16,
                     arity: 2,
                     private?: false
                   },
                   %Defined{
                     name: :no_head,
                     start_line: 2,
                     end_line: 8,
                     arity: 2,
                     private?: false
                   }
                 ]
               }
             ] = actual
    end

    test "deep function" do
      actual = process_file("test/priv/functions/deeper.ex")

      assert [
               %ModuleInfo{
                 defs: [
                   %Defined{
                     name: :deeper,
                     start_line: 2,
                     end_line: 9,
                     arity: 2,
                     private?: false
                   }
                 ]
               }
             ] = actual
    end

    test "with attributes" do
      actual = process_file("test/priv/functions/with_attributes.ex")

      assert [
               %ModuleInfo{
                 defs: [
                   %Defined{
                     name: :foo,
                     start_line: 2,
                     end_line: 5,
                     arity: 1,
                     private?: false
                   },
                   %Defined{
                     name: :bar,
                     start_line: 7,
                     end_line: 10,
                     arity: 1,
                     private?: false
                   }
                 ]
               }
             ] = actual
    end
  end
end
