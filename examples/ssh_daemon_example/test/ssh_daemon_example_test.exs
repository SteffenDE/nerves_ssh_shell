defmodule SSHDaemonExampleTest do
  use ExUnit.Case
  doctest SSHDaemonExample

  test "greets the world" do
    assert SSHDaemonExample.hello() == :world
  end
end
