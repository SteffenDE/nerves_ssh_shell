defmodule NervesSshShellTest do
  use ExUnit.Case
  doctest NervesSshShell

  test "greets the world" do
    assert NervesSshShell.hello() == :world
  end
end
