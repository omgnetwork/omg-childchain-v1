defmodule OMG.ChildChain.MixProject do
  use Mix.Project

  def project() do
    [
      app: :omg_child_chain,
      version: "#{String.trim(File.read!("../../VERSION"))}",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application() do
    [
      extra_applications: [:logger, :telemetry],
      start_phases: [{:boot_done, []}, {:attach_telemetry, []}],
      mod: {OMG.ChildChain.Application, []}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:prod), do: ["lib"]
  defp elixirc_paths(:dev), do: ["lib"]
  defp elixirc_paths(:test), do: ["lib", "test/support"]

  defp deps() do
    case Mix.env() do
      :prod -> [{:gas, git: "https://github.com/omgnetwork/gas.git", branch: "main"}]
      _ -> []
    end ++
      [
        {:fake_server, "~> 2.1", only: [:test], runtime: false},
        {:telemetry, "~> 0.4.1"},
        #
        {:omg_bus, in_umbrella: true},
        {:omg, in_umbrella: true},
        {:omg_status, in_umbrella: true},
        {:omg_db, in_umbrella: true},
        {:omg_eth, in_umbrella: true},
        {:omg_utils, in_umbrella: true}
      ]
  end
end
