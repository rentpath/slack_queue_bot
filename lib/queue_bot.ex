defmodule QueueBot do
  use Application
  use Supervisor
  require Logger

  @moduledoc """
  A chatbot queue for slack.
  """

  @port Application.get_env(:queue_bot, :server)[:port]

  def start(_type, _args) do
    maybe_set_slack_token()

    children = [
      {QueueBot.Redis, :redis},
      Plug.Adapters.Cowboy.child_spec(:http, QueueBot.Router, [], port: @port),
      QueueBot.Manager
    ]

    Logger.info "Started application"

    Supervisor.start_link(children, strategy: :one_for_one)
  end

  defp maybe_set_slack_token do
    env = Application.get_env(:queue_bot, :slack)
    if env[:token] == nil && env[:token_fetch_command] != nil do
      token =
        env[:token_fetch_command]
        |> String.to_charlist
        |> :os.cmd
        |> to_string
        |> String.trim

      new_slack_env = Keyword.put(env, :token, token)
      Application.put_env(:queue_bot, :slack, new_slack_env)
    end
  end
end
