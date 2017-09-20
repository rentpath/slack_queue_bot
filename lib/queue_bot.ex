defmodule QueueBot do
  use Application
  use Supervisor
  require Logger

  @moduledoc """
  Documentation for QueueBot.
  """

  def start(_type, _args) do
    children = [
      Plug.Adapters.Cowboy.child_spec(:http, QueueBot.Router, [], port: 4000),
      worker(QueueBot.Manager, [:manager])
    ]

    Logger.info "Started application"

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
