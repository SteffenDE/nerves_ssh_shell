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
      {:ex_pty, github: "SteffenDE/ex_pty", branch: "main"}
    ]
  end
end
