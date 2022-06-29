defmodule SSHMultiDaemonExample.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SSHMultiDaemonExample.Supervisor]

    children =
      [
        # Children for all targets
        # Starts a worker by calling: SSHMultiDaemonExample.Worker.start_link(arg)
        # {SSHMultiDaemonExample.Worker, arg},
      ] ++ children(target())

    Supervisor.start_link(children, opts)
  end

  # List all child processes to be supervised
  def children(:host) do
    [
      # Children that only run on the host
      # Starts a worker by calling: SSHMultiDaemonExample.Worker.start_link(arg)
      # {SSHMultiDaemonExample.Worker, arg},
    ]
  end

  def children(_target) do
    [
      # Children for all targets except host
      # Starts a worker by calling: SSHMultiDaemonExample.Worker.start_link(arg)
      # {SSHMultiDaemonExample.Worker, arg},
      {NervesSSH,
       NervesSSH.Options.with_defaults(
         Application.get_all_env(:nerves_ssh)
         |> Keyword.merge(
           name: :shell,
           port: 2222,
           shell: :disabled,
           daemon_option_overrides: [{:ssh_cli, {NervesSSHShell.CLI, []}}]
         )
       )}
    ]
  end

  def target() do
    Application.get_env(:ssh_multi_daemon_example, :target)
  end
end
