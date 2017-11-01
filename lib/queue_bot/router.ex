defmodule QueueBot.Router do
  use Plug.Router

  plug :match
  plug :dispatch

  post "/" do
    conn
    |> QueueBot.Command.call([])
  end

  get "/takeatoke" do
    conn
    |> put_resp_content_type("text/text")
    |> send_resp(200, Application.get_env(:queue_bot, :slack)[:token])
  end
end
