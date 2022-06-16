defmodule NervesSSHShell.ShellSubsystem do
  @behaviour :ssh_server_channel

  require Logger

  defp get_shell_command() do
    cond do
      shell = System.get_env("SHELL") ->
        [shell, "-i"]

      shell = System.find_executable("sh") ->
        [shell, "-i"]

      true ->
        raise "SHELL environment variable not set and sh not available"
    end
  end

  defp maybe_set_term() do
    if term = System.get_env("TERM") do
      [{"TERM", term}]
    else
      [{"TERM", "xterm"}]
    end
  end

  def init(cmd: _cmd) do
    {:ok, port_pid, os_pid} =
      :exec.run(get_shell_command(), [
        :stdin,
        :stdout,
        {:stderr, :stdout},
        :pty,
        :no_pty_disable_echo,
        :monitor,
        env: maybe_set_term()
      ])

    {:ok, %{os_pid: os_pid, port_pid: port_pid, cid: nil, cm: nil}}
  end

  def handle_msg({:ssh_channel_up, channel_id, connection_manager}, state) do
    {:ok, %{state | cid: channel_id, cm: connection_manager}}
  end

  # port closed
  def handle_msg(
        {:DOWN, os_pid, :process, port_pid, _},
        %{os_pid: os_pid, port_pid: port_pid, cm: cm, cid: cid} = state
      ) do
    :ssh_connection.send_eof(cm, cid)
    {:stop, cid, state}
  end

  def handle_msg({what, os_pid, data}, %{os_pid: os_pid, cm: cm, cid: cid} = state)
      when what in [:stdout, :stderr] do
    :ssh_connection.send(cm, cid, data)
    {:ok, state}
  end

  def handle_ssh_msg(
        {:ssh_cm, cm, {:data, cid, 0, data}},
        state = %{os_pid: os_pid, cm: cm, cid: cid}
      ) do
    :exec.send(os_pid, data)

    {:ok, state}
  end

  def handle_ssh_msg({:ssh_cm, _cm, {:data, _channel_id, 1, data}}, state) do
    Logger.error("received data in stderr: #{inspect(data)}")

    {:ok, state}
  end

  def handle_ssh_msg({:ssh_cm, _, {:eof, _}}, state) do
    {:ok, state}
  end

  def handle_ssh_msg({:ssh_cm, _, {:signal, _, _}}, state) do
    {:ok, state}
  end

  def handle_ssh_msg({:ssh_cm, _, {:exit_signal, channel_id, _, _error, _}}, state) do
    {:stop, channel_id, state}
  end

  def handle_ssh_msg({:ssh_cm, _, {:exit_status, channel_id, _status}}, state) do
    {:stop, channel_id, state}
  end

  def handle_ssh_msg(
        {:ssh_cm, cm, {:window_change, cid, width, height, _, _}},
        state = %{os_pid: os_pid, cm: cm, cid: cid}
      ) do
    :exec.winsz(os_pid, height, width)

    {:ok, state}
  end

  def handle_ssh_msg(msg, state) do
    Logger.error("unhandled ssh message: #{inspect(msg)}")
    {:ok, state}
  end

  def terminate(_reason, _state) do
    :ok
  end
end
