defmodule Ui.Scene.Home do
  use Scenic.Scene

  alias Scenic.Graph

  import Scenic.Primitives
  # import Scenic.Components

  alias Ui.Components.BodyDiff

  @graph Graph.build(font: :roboto, font_size: 24)
  |> rect({700, 600}, fill: :white, id: :background)
  |> BodyDiff.add_to_graph("", translate: {0, 0})

  def init(_, _) do
    push_graph( @graph )
    {:ok, @graph}
  end
end
