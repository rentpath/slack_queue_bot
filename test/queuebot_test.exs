defmodule QueueBotTest do
  use ExUnit.Case
  doctest QueueBot

  test "greets the world" do
    assert QueueBot.hello() == :world
  end
end
