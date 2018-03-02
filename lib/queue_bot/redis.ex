defmodule QueueBot.Redis do
  @redis_client Application.get_env(:queue_bot, :redis_client)

  def start_link(name) do
    case @redis_client[:use_redis] do
      true -> start_redis(name)
      _ -> :ignore
    end
  end

  def child_spec(args) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [args]}
    }
  end

  defp start_redis(name) do
    {:ok, client} = Exredis.start_link
    true = Process.register(client, name)
    {:ok, client}
  end
end
