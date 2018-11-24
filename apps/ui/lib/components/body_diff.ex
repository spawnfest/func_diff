defmodule Ui.Components.BodyDiff do
  use Scenic.Component, has_children: false

  alias Scenic.Graph
  alias Scenic.Primitive
  alias Scenic.ViewPort

  import Scenic.Primitives

  @impl Scenic.Component
  def info(_) do
    ""
  end

  @impl Scenic.Component
  def verify(data) do
    {:ok, data}
  end

  @impl Scenic.Scene
  def init(_data, _opts) do
    Graph.build(font: :roboto_mono, font_size: 14)
    |> rect({200, 200}, fill: :blue, id: :background)
    |> push_graph

    {:ok, nil}
  end

end
