defmodule QueueBot.Router do
  use Plug.Router

  plug :match
  plug :dispatch

  post "/" do
    conn
    |> QueueBot.Command.call([])
  end
end
