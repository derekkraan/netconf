defmodule NetconfTest do
  use ExUnit.Case
  doctest Netconf

  test "greets the world" do
    assert Netconf.hello() == :world
  end
end
