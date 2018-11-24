defmodule Runner.DiffTest do
  use ExUnit.Case

  import Runner.Diff

  test "diff output" do
    output = diff(File.read!("test/priv/text1"), File.read!("test/priv/text2"))

    expected = [
      {:add, "line0"},
      {:common, "line1"},
      {:common, "line2"},
      {:del, "line3"},
      {:add, "line4"},
      {:common, "line5"},
      {:del, "line6"}
    ]

    assert expected == output
  end
end
