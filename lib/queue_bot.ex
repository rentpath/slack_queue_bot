defmodule QueueBot do
  use Application
  use Supervisor
  require Logger

  @moduledoc """
  A chatbot queue for slack.
  """

  @port Application.get_env(:queue_bot, :server)[:port]

  def start(_type, _args) do
    children = [
      Plug.Adapters.Cowboy.child_spec(:http, QueueBot.Router, [], port: @port),
      worker(QueueBot.Manager, [:manager])
    ]

    Logger.info "Started application"

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
