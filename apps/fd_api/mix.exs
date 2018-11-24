defmodule FuncDiffAPI.MixProject do
  use Mix.Project

  def project do
    [
      app: :fd_api,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:runner, in_umbrella: true},
      {:parser, in_umbrella: true}
    ]
  end
end
