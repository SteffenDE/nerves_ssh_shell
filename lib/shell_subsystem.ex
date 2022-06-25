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

  # defp maybe_set_term() do
  #   if term = System.get_env("TERM") do
  #     [{"TERM", term}]
  #   else
  #     [{"TERM", "xterm"}]
  #   end
  # end

  def init(_opts) do
    port = ExPty.open(get_shell_command())

    {:ok, %{port: port, cid: nil, cm: nil}}
  end

  def handle_msg({:ssh_channel_up, channel_id, connection_manager}, state) do
    {:ok, %{state | cid: channel_id, cm: connection_manager}}
  end

  # port closed
  def handle_msg(
        {:EXIT, port, _reason},
        %{port: port, cm: cm, cid: cid} = state
      ) do
    :ssh_connection.send_eof(cm, cid)
    {:stop, cid, state}
  end

  def handle_msg({port, {:data, data}} = _msg, %{cm: cm, cid: cid, port: port} = state) do
    :ssh_connection.send(cm, cid, data)
    {:ok, state}
  end

  def handle_ssh_msg(
        {:ssh_cm, _cm, {:data, channel_id, 0, data}},
        state = %{port: port, cid: channel_id}
      ) do
    ExPty.send_data(port, data)

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
        {:ssh_cm, cm, {:window_change, cid, width, height, _, _} = _msg},
        state = %{cm: cm, cid: cid, port: port}
      ) do
    ExPty.winsz(port, height, width)

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
