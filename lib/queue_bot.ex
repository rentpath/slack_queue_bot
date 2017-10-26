defmodule QueueBot do
  use Application
  use Supervisor
  require Logger

  @moduledoc """
  A chatbot queue for slack.
  """

  @port Application.get_env(:queue_bot, :server)[:port]

  def start(_type, _args) do
    children = redis_worker() ++ [
      Plug.Adapters.Cowboy.child_spec(:http, QueueBot.Router, [], port: @port),
      worker(QueueBot.Manager, [])
    ]

    Logger.info "Started application"

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  defp redis_worker do
    if Application.get_env(:queue_bot, :redis_client)[:use_redis] do
      [worker(QueueBot.Redis, [:redis])]
    else
      []
    end
  end
end
