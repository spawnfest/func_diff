defmodule Ui.Scene.Home do
  use Scenic.Scene

  alias Scenic.Graph

  import Scenic.Primitives
  # import Scenic.Components

  alias Ui.Components.BodyDiff

  @graph Graph.build(font: :roboto, font_size: 24)
  |> BodyDiff.add_to_graph("")

  def init(_, _) do
    push_graph( @graph )
    {:ok, @graph}
  end
end
