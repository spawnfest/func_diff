defmodule Ui.Scene.Home do
  use Scenic.Scene

  alias Scenic.Graph

  import Scenic.Primitives
  # import Scenic.Components

  @note """
    This is a very simple starter application.

    If you want a more full-on example, please start from:

    mix scenic.new.example
  """

  @graph Graph.build(font: :roboto, font_size: 24)
  |> text(@note, translate: {20, 60})

  # ============================================================================
  # setup

  # --------------------------------------------------------
  def init(_, _) do
    push_graph( @graph )
    {:ok, @graph}
  end
end
