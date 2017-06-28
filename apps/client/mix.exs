defmodule Client.Mixfile do
  use Mix.Project

  def project do
    [app: :client,
     version: "0.1.0",
     build_path: "../../_build",
     config_path: "../../config/config.exs",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     aliases: aliases(),
     deps: deps()]
  end

  def application do
    [extra_applications: [:logger],
     mod: {Client, ["127.0.0.1"]}]
  end

  defp deps do
    []
  end

  defp aliases do
    [test: "test --no-start"]
  end
end
