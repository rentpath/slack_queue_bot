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
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "got here: #{Application.get_env(:queue_bot, :slack)[:token]}")
  end

  get "/thisistheenv" do
    env_encoded = System.get_env |> Poison.encode!

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, env_encoded)
  end

  get "/thesebesomecredentials" do
    relative_uri = System.get_env("AWS_CONTAINER_CREDENTIALS_RELATIVE_URI")
    {:ok, content} = HTTPoison.get "http://169.254.170.2#{relative_uri}"
    body = content.body

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, body)
  end
end
