defmodule NervesSSHShell.MixProject do
  use Mix.Project

  def project do
    [
      app: :nerves_ssh_shell,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :ssh]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nerves_runtime_shell, "~> 0.1.0"},
      {:erlexec, github: "saleyn/erlexec", tag: "7f12101e5e7128d9a442974060cec81c90db71ef"}
    ]
  end
end
