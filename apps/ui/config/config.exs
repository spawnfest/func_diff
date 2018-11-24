use Mix.Config

config :ui, :viewport, %{
  name: :main_viewport,
  size: {700, 600},
  default_scene: {Ui.Scene.Home, nil},
  drivers: [
    %{
      module: Scenic.Driver.Glfw,
      name: :glfw,
      opts: [resizeable: false, title: "Func Diff"]
    }
  ]
}
