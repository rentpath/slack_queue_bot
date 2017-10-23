defmodule QueueBot.Redis do
  def start_link(name) do
    {:ok, client} = Exredis.start_link
    true = Process.register(client, name)
    {:ok, client}
  end
end
