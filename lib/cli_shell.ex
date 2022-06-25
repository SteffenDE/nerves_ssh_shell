defmodule NervesSSHShell.CLI do
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

  # defp maybe_set_term(nil) do
  #   if term = System.get_env("TERM") do
  #     [{"TERM", term}]
  #   else
  #     [{"TERM", "xterm"}]
  #   end
  # end

  # defp maybe_set_term({term, _, _, _, _, _}) when is_list(term),
  #   do: [{"TERM", List.to_string(term)}]

  defp maybe_set_window_size(_port, nil), do: :ok

  defp maybe_set_window_size(port, {_term, width, height, _, _, _}) do
    # set initial window size in background, as is does not seem to work
    # when doing it too early after creating the process
    spawn(fn ->
      Process.sleep(100)
      ExPty.winsz(port, height, width)
    end)
  end

  defp exec_command(cmd, %{pty_opts: pty_opts, env: _env}) do
    case pty_opts do
      nil ->
        port = ExPty.open(cmd)

        {:ok, port}

      pty_opts ->
        port = ExPty.open(cmd)

        maybe_set_window_size(port, pty_opts)
        {:ok, port}
    end
  end

  def init(_) do
    {:ok, %{port: nil, pty_opts: nil, cid: nil, cm: nil, env: []}}
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

  def handle_msg(msg, state) do
    Logger.error("unhandled message: #{inspect(msg)}")
    {:ok, state}
  end

  def handle_ssh_msg({:ssh_cm, cm, {:pty, cid, want_reply, pty_opts} = _msg}, state = %{cm: cm}) do
    :ssh_connection.reply_request(cm, want_reply, :success, cid)

    {:ok, %{state | pty_opts: pty_opts}}
  end

  def handle_ssh_msg(
        {:ssh_cm, cm, {:env, cid, want_reply, key, value}},
        state = %{cm: cm, cid: cid}
      ) do
    :ssh_connection.reply_request(cm, want_reply, :success, cid)

    {:ok, update_in(state, [:env], fn vars -> [{key, value} | vars] end)}
  end

  def handle_ssh_msg(
        {:ssh_cm, cm, {:exec, cid, want_reply, command}},
        state = %{cm: cm, cid: cid}
      )
      when is_list(command) do
    {:ok, port} = exec_command(List.to_string(command) |> OptionParser.split(), state)
    :ssh_connection.reply_request(cm, want_reply, :success, cid)
    {:ok, %{state | port: port}}
  end

  def handle_ssh_msg(
        {:ssh_cm, cm, {:shell, cid, want_reply} = _msg},
        state = %{cm: cm, cid: cid}
      ) do
    {:ok, port} = exec_command(get_shell_command(), state)
    :ssh_connection.reply_request(cm, want_reply, :success, cid)
    {:ok, %{state | port: port}}
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

  def handle_ssh_msg({:ssh_cm, _, {:signal, _, _} = _msg}, state) do
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
