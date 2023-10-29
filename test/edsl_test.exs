defmodule EdslTest do
  use ExUnit.Case
  doctest Edsl

  test "greets the world" do
    assert Edsl.hello() == :world
  end
end
