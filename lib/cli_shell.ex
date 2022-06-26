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

  defp maybe_set_term(nil) do
    if term = System.get_env("TERM") do
      [{"TERM", term}]
    else
      [{"TERM", "xterm"}]
    end
  end

  defp maybe_set_term({term, _, _, _, _, _}) when is_list(term),
    do: [{"TERM", List.to_string(term)}]

  defp maybe_add_env(term_env, env) do
    if Enum.any?(env, fn env ->
         match?("TERM=" <> _, env) or match?({"ENV", _}, env)
       end) do
      env
    else
      term_env ++ env
    end
  end

  def init(_) do
    {:ok, pty} = ExPTY.start_link()

    {:ok,
     %{
       pty: pty,
       pty_opts: nil,
       cid: nil,
       cm: nil,
       env: []
     }}
  end

  def handle_msg({:ssh_channel_up, channel_id, connection_manager}, state) do
    {:ok, %{state | cid: channel_id, cm: connection_manager}}
  end

  # pty closed
  def handle_msg(
        {:EXIT, pty, _reason},
        %{pty: pty, cm: cm, cid: cid} = state
      ) do
    :ssh_connection.send_eof(cm, cid)
    {:stop, cid, state}
  end

  def handle_msg({pty, {:data, data}} = _msg, %{cm: cm, cid: cid, pty: pty} = state) do
    :ssh_connection.send(cm, cid, data)
    {:ok, state}
  end

  def handle_msg(msg, state) do
    Logger.error("unhandled message: #{inspect(msg)}")
    {:ok, state}
  end

  def handle_ssh_msg(
        {:ssh_cm, cm, {:pty, cid, want_reply, pty_opts} = _msg},
        state = %{pty: pty, cm: cm}
      ) do
    {_term, cols, rows, _, _, pty_settings} = pty_opts
    ExPTY.set_pty_opts(pty, pty_settings)
    ExPTY.winsz(pty, rows, cols)
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
        state = %{pty: pty, cm: cm, cid: cid, pty_opts: pty_opts, env: env}
      )
      when is_list(command) do
    ExPTY.exec(
      pty,
      List.to_string(command) |> OptionParser.split(),
      pty_opts |> maybe_set_term() |> maybe_add_env(env)
    )

    :ssh_connection.reply_request(cm, want_reply, :success, cid)
    {:ok, %{state | pty: pty}}
  end

  def handle_ssh_msg(
        {:ssh_cm, cm, {:shell, cid, want_reply} = _msg},
        state = %{pty: pty, cm: cm, cid: cid, pty_opts: pty_opts, env: env}
      ) do
    ExPTY.exec(pty, get_shell_command(), pty_opts |> maybe_set_term() |> maybe_add_env(env))
    :ssh_connection.reply_request(cm, want_reply, :success, cid)
    {:ok, %{state | pty: pty}}
  end

  def handle_ssh_msg(
        {:ssh_cm, _cm, {:data, channel_id, 0, data}},
        state = %{pty: pty, cid: channel_id}
      ) do
    ExPTY.send_data(pty, data)

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
        state = %{cm: cm, cid: cid, pty: pty}
      ) do
    ExPTY.winsz(pty, height, width)

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
