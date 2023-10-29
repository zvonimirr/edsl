defmodule Edsl.MixProject do
  use Mix.Project

  def project do
    [
      app: :edsl,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Edsl.Application, []}
    ]
  end

  defp deps do
    [
      {:yaml, "~> 0.1.0"}
    ]
  end
end
